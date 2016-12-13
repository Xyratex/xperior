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
# Please  visit http://www.xyratex.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

XpMongo - Functions which used to work with  MongoDB and Xperior results

=cut

package XpMongo;
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use File::Basename;
use English;
use Carp;
use Cwd;
use YAML::Syck;
local $YAML::Syck::ImplicitTyping = 1;
use File::Find;
use POSIX;
use Data::Dumper;
use MongoDB;
use MongoDB::OID;
use MongoDB::GridFS;
use MongoDB::Connection;
use JSON;
use DateTime;    #fix for faliure

our @ISA;
our @EXPORT;
our @EXPORT_OK;

our $dbname     = "lustre";      # default name which used in tests
our $collection = "tresults";    # default db which used in tests
our $host       = "localhost";


BEGIN {
    @ISA           = ("Exporter");
    @EXPORT        = qw(&opendb &post &remove_by_field);
    @EXPORT_OK     = qw($dbname $collection $host );
    Log::Log4perl->easy_init( { level => $DEBUG } );
}

sub opendb {
    INFO "Connecting to MongoDB";
    my $conn = MongoDB::Connection->new( host => $host )
      or confess "The server cannot be reached";
    my $db = $conn ->get_database($dbname);
    my $stat = $db->run_command( { serverStatus => -1 } );
    INFO "MongoDB ver: " . $stat->{version} . "\n";

    #my $collection = $db->lustre;
    return $db;
}

sub _iterate_hash {
    my $hash = shift;
    my %newhash;
    while ( my ( $key, $value ) = each %$hash ){
        if ( 'HASH' eq ref $value ) {
             $newhash{$key}  =  _iterate_hash($value);
        }
        else {

            #convert
            if ( $key =~ m/\./ ) {
                #delete( $hash->{$key} );
                $key =~ s/\./_pnt_/g;
                $newhash{$key} = $value;

                #DEBUG "new value: [".$hash->{$key}."]";
            }else{
                $newhash{$key} = $value;
            }
        }
    }
    return \%newhash;
}

sub _validate_doc_data {
    my ($data) = @_;
    my $starttime = int( $data->{extoptions}->{sessionstarttime} );
    $data->{extoptions}->{sessionstarttime} = $starttime;

    #move data to the root level for better performance
    $data->{sessionstarttime} = $starttime;
    $data->{cli_branch_name} = $data->{extoptions}->{cli_branch};
    $data->{srv_branch_name} = $data->{extoptions}->{srv_branch};

    # replacing . to _pnt_ in keys
    my $return_data = _iterate_hash($data);
    return $return_data;
}

sub _post_yaml_doc {
    my ( $db, $file, $attach ) = @_;
    my ( $name, $basedir, $suffix ) = fileparse( $file, ".yaml" );
    #INFO "Posting document: $name";
    my $yaml_data = YAML::Syck::LoadFile($file);

    my $grid = $db->get_gridfs;
    my @ids;
    foreach my $a (@{$attach}){
        my $attach_file = basename($a);
        my $fh = IO::File->new($a, "r") or confess "Cannot open attachement file [$a]";
        my $id = $grid->insert($fh, {
            "filename"  => $attach_file,
            "test"      => $yaml_data->{'id'},
            "starttime" => $yaml_data->{'starttime'},
        });
        DEBUG "Added attachment for test [$yaml_data->{'id'}]: [$attach_file]";
        push @ids, $id;
    }
    $yaml_data->{attachments_ids}=\@ids;
    my $validated_yaml = _validate_doc_data($yaml_data);

    $db->get_collection($collection)->insert($validated_yaml);    #,safe=>1);

    my $err = $db->last_error();
    return defined ($validated_yaml->{srv_branch_name});
}


sub post {
    my ( $start_folder, @params ) = @_;

    my $test_results_db = opendb();
    my @yamls;
    my @otherfiles;
    find(
        sub {
            if (/\.yaml$/) {
                push( @yamls, $File::Find::name );
            }
            else {
                push( @otherfiles, $File::Find::name );
            }
        },
        $start_folder
    );

    my $item  = 0;
    my $count = scalar @yamls;
    for my $yaml_doc (@yamls) {
        my $tname = $yaml_doc;
        $tname =~ s/\.yaml//;
        my @attachments;
        foreach my $file (@otherfiles) {
            if ( $file =~ m/^$tname\./ ) {
                push @attachments, $file;
            }
        }
        _post_yaml_doc( $test_results_db, $yaml_doc, \@attachments );
        $item += 1;
        INFO int( ( $item * 100 ) / $count ), "% processed\n";
    }
    return;
}

sub remove_by_sessionstarttime_old{
    my ($dry, $sessionstarttime ) = @_;
    DEBUG "dry=[$dry], sessionstarttime=[$sessionstarttime]";
    my $db = opendb();
    my $grid = $db->get_gridfs;
    my $c=0;
    #get list of items

    #map-reduce based on assumption that sessionstarttime is session id.
    #TODO think about use more uniq session id
my $map = <<MAP;
function() {
    var r = this.extoptions;

    var id =
          this.extoptions.branch + "_"
        + this.extoptions.type + "_"
        + this.extoptions.ofed + "_"
        + this.extoptions.arch + "_"
        + this.extoptions.sessionstarttime;
    emit(id, r);
}
MAP
;

my $reduce = <<REDUCE;
function(k, values) {
    return values[0];
}
REDUCE
;
    my $cmd = Tie::IxHash->new(
        "mapreduce" => $collection,
        "out"       => "1",
        "map"       => $map,
        "reduce"    => $reduce
    );
    my $result = $db->run_command($cmd);
    my $err = $db->last_error();
    my $res_coll = $result->{'result'};
    my $cl = $db->get_collection($res_coll);
    my $cur1 = $cl->query( {}, { limit => 1000 } );
    my $targetextopt = undef;
    while ($cur1->has_next) {
        my $res = $cur1->next;
        #print Dumper $res;
        if($res->{value}->{sessionstarttime} == $sessionstarttime ){
            $targetextopt = $res->{value};
        }
    }
    if( not defined($targetextopt)){
        ERROR
            "No session by sessionstarttime [$sessionstarttime] found";
        return -1;
    };

    #very strange woraround. need deep investigation in mongodb driver
    #TODO avoid this direct setting
    my %dh =  (
  branch   => $targetextopt->{branch},
  arch     => $targetextopt->{arch},
  buildurl => $targetextopt->{buildurl},
  configuration => $targetextopt->{configuration},
  distr         => $targetextopt->{distr},
  executiontype => $targetextopt->{executiontype},
  ofed          => $targetextopt->{ofed},
  release       => $targetextopt->{release},
  sessionstarttime => $targetextopt->{sessionstarttime},
  type          => $targetextopt->{type}
  );
    print Dumper \%dh;
    print "\n-------\n";
    print Dumper $targetextopt;
    my $cursor = $db->${collection}->find(
            {extoptions  => \%dh});
    #iterate over all results
     while ($cursor->has_next) {
        my $res = $cursor->next;
        #iterate of attachments
        foreach my $a(@{$res->{'attachments_ids'}}){
            #remove attachemnt
            DEBUG "Remove attachement $a";
            $grid->delete($a) if $dry > 0;;
        }
        #remove result
        INFO "Remove record  [$res->{_id}]";
        $db->$collection->remove({_id => $res->{_id}}) if $dry > 0;
        my $err = $db->last_error();
        if( (not defined( $err)) or ($err->{ok} != 1)){
            ERROR "Error is:".Dumper $err;
        }
        $c++;
    }
    INFO "Deleted $c records";
}

sub remove_by_field{
    my ($dry, $field, $value ) = @_;
    DEBUG "dry=[$dry], [$field]=[$value]";
    my $db = opendb();
    my $grid = $db->get_gridfs;
    my $c=0;
    #get list of items

    my $cursor = $db->${collection}->find(
    { $field  => $value});
    #{'extoptions.executiontype' => "IT"});
    #iterate over all results
     while ($cursor->has_next) {
        my $res = $cursor->next;
        #iterate of attachments
        #TODO remove in threads all in same time
        foreach my $a(@{$res->{'attachments_ids'}}){
            #remove attachemnt
            DEBUG "Remove attachement $a";
            $grid->delete($a) if $dry > 0;;
        }
        #remove result
        INFO "Remove record  [$res->{_id}]:"
            ." $res->{groupname}.$res->{id} "
            ." for branch $res->{extoptions}->{branch}";
        $db->$collection->remove({_id => $res->{_id}}) if $dry > 0;
        my $err = $db->last_error();
        if( (not defined( $err)) or ($err->{ok} != 1)){
            ERROR "Error is:".Dumper $err;
        }
        $c++;
    }
    INFO "Deleted $c records";
}
1;

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 only,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License version 2 for more details (a copy is included
in the LICENSE file that accompanied this code).

You should have received a copy of the GNU General Public License
version 2 along with this program; If not, see http://www.gnu.org/licenses



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut


