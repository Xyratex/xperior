#
#===============================================================================
#
#         FILE:  XpMongo.pm
#
#  DESCRIPTION:  Functions which used to work with  MongoDB and Xperior results
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  05/10/2012 04:11:36 PM
#===============================================================================

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
    @EXPORT        = qw(&opendb &post &remove_by_sessionstarttime);
    @EXPORT_OK     = qw($dbname $collection $host );
    Log::Log4perl->easy_init( { level => $DEBUG } );
}

sub opendb {
    INFO "Connecting to MongoDB";
    my $conn = MongoDB::Connection->new( host => $host )
      or confess "The server cannot be reached";
    my $db = $conn ->${dbname};
    my $stat = $db->run_command( { serverStatus => -1 } );
    INFO "MongoDB ver: " . $stat->{version} . "\n";

    #my $collection = $db->lustre;
    return $db;
}

sub _iterate_hash {
    my $hash = shift;
    while ( my ( $key, $value ) = each %$hash ) {
        if ( 'HASH' eq ref $value ) {
            _iterate_hash($value);
        }
        else {

            #convert
            if ( $key =~ m/\./ ) {
                delete( $hash->{$key} );
                $key =~ s/\./_pnt_/g;
                $hash->{$key} = $value;

                #DEBUG "new value: [".$hash->{$key}."]";
            }
        }
    }
    return;
}

sub _validate_doc_data {
    my ($data) = @_;
    $data->{extoptions}->{sessionstarttime} =
      int( $data->{extoptions}->{sessionstarttime} );

    # replacing . to _pnt_ in keys
    _iterate_hash($data);
    return;
}

sub _post_yaml_doc {
    my ( $db, $file, $ats ) = @_;
    my ( $name, $basedir, $suffix ) = fileparse( $file, ".yaml" );
    #INFO "Posting document: $name";
    my $yaml_data = YAML::Syck::LoadFile($file);

    my $grid = $db->get_gridfs;
    my @aids;
    foreach my $a (@{$ats}){
        my $fh = IO::File->new($a, "r") or confess "Cannot open file [$a]";
        my $sa= 'no_name';        
        if($a =~ m/[\/\\]([^\/\\]+)$/){
            $sa = $1;
        }
        my $id = $grid->insert($fh, {"filename" => $sa,"test"=> $yaml_data->{'id'}});        
        push @aids,$id;
    }
    $yaml_data->{attachments_ids}=\@aids;;
    _validate_doc_data($yaml_data);

    $db ->${collection}->insert($yaml_data);    #,safe=>1);    

    my $err = $db->last_error();

    #INFO "Last error". Dumper $err;
    #TODO atach files
    #INFO "Added document [$doc->{id}]";
    return;
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

sub remove_by_sessionstarttime{
    my ($dry, $sessionstarttime ) = @_;
    DEBUG "dry=[$dry], sessionstarttime=[$sessionstarttime]";
    my $db = opendb();
    my $grid = $db->get_gridfs;
    my $c=0;
    #get list of items

    my $cursor = $db->${collection}->find(
    {'extoptions.sessionstarttime'  => $sessionstarttime});
    #{'extoptions.executiontype' => "IT"});           
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

