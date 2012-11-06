#
# GPL HEADER START
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 only,
# as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License version 2 for more details (a copy is included
# in the LICENSE file that accompanied this code).
#
# You should have received a copy of the GNU General Public License
# version 2 along with this program; If not, see http://www.gnu.org/licenses
# 
# Please  visit http://www.xyratex.com/contact if you need additional information or
# have any questions.
# 
# GPL HEADER END
# 
# Copyright 2012 Xyratex Technology Limited
# 
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

package mongo;

use strict;
use warnings;
use Test::Able;
use Test::More;

use MongoDB;
use MongoDB::OID;
use MongoDB::Code;
use Carp;
use Data::Dumper;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );

my $collection = "tresults";
my $dbname     = "lustretest";
my $mdir       = 'mongo/js/';
my $rdir       = 'mongo/t/data';
my $dropcmd    = "mongo $dbname --eval 'db.dropDatabase();'";
my $uploadcmd =
  "mongo/bin/upload.pl --post " . "--folder='$rdir' " . "--database='$dbname' ";

my $db;
my $grid;

sub opendb {
    INFO "Connecting to MongoDB";
    my $conn = MongoDB::Connection->new( host => 'localhost' )
      or die "The server cannot be reached";
    my $db = $conn ->${dbname};
    my $stat = $db->run_command( { serverStatus => -1 } );
    INFO "MongoDB ver: " . $stat->{version} . "\n";
    return $db;
}

sub loadFunction {
    my $fname = shift;
    open( FILE, "$mdir/$fname.js" )
      or confess "Can't open $mdir/$fname.js: $!\n";
    my $fbody = do { local $/; <FILE> };
    return $fbody;
}

sub doMapReduce {
    my ($mrname,$col) = @_;
    $col = 0  unless defined $col;

    my $map    = loadFunction( $mrname . '_m' );
    my $reduce = loadFunction( $mrname . '_r' );

    my $cmd = Tie::IxHash->new(
        "mapreduce" => $collection,
        "out"       => "1",
        "map"       => $map,
        "reduce"    => $reduce
    );

    #DEBUG Dumper $cmd;

    my $result = $db->run_command($cmd);

    #DEBUG Dumper $result;
    my $err = $db->last_error();
    DEBUG Dumper $err;

    my $res_coll = $result->{'result'};
    DEBUG "result collection is $res_coll\n";
    return $res_coll if ($col == 1);

    my $cl = $db->get_collection($res_coll);
    my $c = $cl->query( {}, { limit => 1000 } );
    return $c;
}

######### test class configuration

my %options = ();

startup startup => sub {
    Log::Log4perl->easy_init($DEBUG);

};
setup setup => sub {

    $db = opendb;
    confess "DB is not defined " unless defined $db;

    #$db->${collection}->drop;
    $db->dropDatabase();
    DEBUG 'Drop result [' . `$dropcmd` . "]\n";

    #mean call uploader while stay in xperior root
    DEBUG "Upload execution : [" . `$uploadcmd` . "]\n";
    $grid = $db->get_gridfs;
};

########################## tests
test
  plan         => 7,
  cCheckUpload => sub {

    #$db->dropDatabase();
    INFO "\n executing cmd [$dropcmd] \n";
    INFO 'Drop result' . `$dropcmd` . "\n";
    my $num = $db ->${collection}->count;
    is( $num, 0, "Count of uploaded records" );
    DEBUG `$uploadcmd`;
    $db  = undef;
    $db  = opendb;
    $num = $db ->${collection}->count;
    is( $num, 99, "Count of uploaded records" );
    my $cursor = $db ->${collection}->find( { id => '21b' } );

    #DEBUG "Cursor is :". Dumper($cursor);
    my $object0 = $cursor->next;
    #DEBUG "Result obj is :" . Dumper($object0);
    is( $object0->{id},                               '21b', "Check obj id" );
    is( scalar( @{ $object0->{'attachments_ids'} } ), 4,     "Attach number" );

    my $af = 0;
    foreach my $aid ( @{$object0->{'attachments_ids'}}){
         my $file = $grid->get($aid);
        if($file->info->{filename} eq '21b.messages.vm1.log'){
            INFO "21b.messages.vm1.log attachemnt found";
            DEBUG "Process attachement [".$aid->{value}."]";
            my $file = $grid->get($aid);
            DEBUG "file is:".Dumper $file->info;
            is($file->info->{test}, '21b', "check test id");
            is($file->info->{test}, '21b', "check test id");
            my $all   = $file->slurp;
            like($all,qr/Installed: perl-YAML-Syck-1.07-4.el6.x86_64/,
                    "Check file end");
            $af =1;
        };
    }
    if( $af == 0){
        fail("Cannot check test id: node attachemnt found");
    }
  };

test
  plan           => 3,
  dCheckRemoving => sub {
    my $num = $db ->${collection}->count;
    is( $num, 99, "initial count of records" );

    DEBUG "Removing:"
      . `mongo/bin/remove.pl --database='$dbname' --sessionstarttime=1331870104`."\n";
    my $nnum = $db ->${collection}->count;
    is( $nnum, ( 99 - 24 ), "count of records after removing" );

    #second removing
    DEBUG "Removing:"
      . `mongo/bin/remove.pl --database='$dbname' --sessionstarttime=1331870104`."\n";
    my $nnum2 = $db ->${collection}->count;
    is( $nnum2, ( 99 - 24 ), "count of records after second removing" );
  };


test
  plan                => 12,
  nCheckProjectStatus => sub {

    my $cursor = doMapReduce('project_status');

    my $object0 = $cursor->next;
    DEBUG "Result obj is :" . Dumper($object0);

    is( $object0->{value}->{configurations}->{'1VM'}->{total},
        33, "check total" );
    is( $object0->{value}->{configurations}->{Cray_Client}->{skipped},
        2, "check skipped" );

    is( $object0->{value}->{branch}, '9777a6', "check branch" );
    is( $object0->{value}->{arch},   'x86_64', "check arch" );

    my $object1 = $cursor->next;
    DEBUG "Result obj is :" . Dumper($object1);

    is( $object1->{value}->{distr}, 'SL61',    "check distr" );
    is( $object1->{value}->{type},  'full',    "check type" );
    is( $object1->{value}->{ofed},  'builtin', "check ofed" );

    is(
        $object1->{_id},
        $object1->{value}->{branch} . "_"
          . $object1->{value}->{type} . "_"
          . $object1->{value}->{ofed} . "_"
          . $object1->{value}->{arch} . "_"
          . $object1->{value}->{distr},
        "check id"
    );

    is( $object1->{value}->{configurations}->{'1VM'}->{passed},
        31, "check passed" );
    is( $object1->{value}->{configurations}->{'1VM'}->{failed},
        1, "check failed" );
    is( $object1->{value}->{configurations}->{'1VM'}->{name},
        '1VM', "check config name" );

    isnt( $cursor->has_next, 0, "No more elements" );
  };

test
  plan                => 5,
  aCheckProjectStatus => sub {

    #DEBUG "##########################################";
    my $col = doMapReduce('branch_status',1);
    my $cursor = $db ->${col}->find( {_id => qr/^b4d01a3cd5_/}  );
    my $object0 = $cursor->next;
    #DEBUG "Result obj0 is :" . Dumper($object0);
     is( $object0->{value}->{status}->{'config'},
        '1VM', "check config name" );

    is( $object0->{value}->{status}->{'total'},
        24, "check total" );


    my $object1 = $cursor->next;
    DEBUG "Result obj1 is :" . Dumper($object1);
    is( $object1->{value}->{branch},
        'b4d01a3cd5', "check config name" );

    is( $object1->{value}->{status}->{'total'},
        9, "check total" );


   my $object2 = $cursor->next;
    DEBUG "Result obj1 is :" . Dumper($object2);

    is($object2,undef,"Check no more results");
  };

teardown some_teardown => sub { };
shutdown some_shutdown => sub { };

mongo->run_tests;

