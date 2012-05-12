#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  mongo_configure.pl
#
#      AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  04/02/2012 04:59:39 PM
#===============================================================================
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
    my $mrname = shift;

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
  plan         => 4,
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
    DEBUG "Result obj is :" . Dumper($object0);
    is( $object0->{id},                               '21b', "Check obj id" );
    is( scalar( @{ $object0->{'attachments_ids'} } ), 4,     "Attach number" );

    #foreach my $aid ( @{$object0->{'attachments_ids'}}){
    #    DEBUG "Process attachement [".$aid->{value}."]";
    #    my $file = $grid->get($aid);
    #    DEBUG "file is:".Dumper $file->info;
    #}
  };

test
  plan           => 3,
  dCheckRemoving => sub {
    my $num = $db ->${collection}->count;
    is( $num, 99, "initial count of records" );

    DEBUG "Removing:"
      . `mongo/bin/remove.pl --database='$dbname' --sessionstarttime='1331870104'`."\n";
    my $nnum = $db ->${collection}->count;
    is( $nnum, ( 99 - 24 ), "count of records after removing" );

    #second removing
    DEBUG "Removing:"
      . `mongo/bin/remove.pl --database='$dbname' --sessionstarttime='1331870104'`."\n";
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

teardown some_teardown => sub { };
shutdown some_shutdown => sub { };

mongo->run_tests;

