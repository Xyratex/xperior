#!/usr/bin/perl 
#===============================================================================

#use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use JSON;

use DateTime;    #fix for faliure

use Carp;
use POSIX;
use Data::Dumper;
use File::Find;
use File::Basename;
use Getopt::Long;

use YAML::Syck;
local $YAML::Syck::ImplicitTyping = 1;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );

my $DBNAME      = "tresults";
my $COLLECTION  = "lustre";
my %COMMAND_MAP = ( 'help' => 'help_command', 'post' => 'post_command' );

sub help_command {
    my ($target) = @_;
    print <<"__HELP__";

XTests CouchDB Upload Results Tool

Usage:
    Bupload-results <command> [<parameters>]

Commands:
  post <folder>      Post document from folder
  TODO connection parameters
  help               Show this message

__HELP__
}

sub opendb {
    INFO "Connecting to MongoDB";
    my $conn = MongoDB::Connection->new( host => 'localhost' )
      or die "The server cannot be reached";
    my $db = $conn ->${DBNAME};
    my $stat = $db->run_command( { serverStatus => -1 } );
    INFO "MongoDB ver: " . $stat->{version} . "\n";

    #my $collection = $db->lustre;
    return $db;
}

sub iterate_hash {
    my $hash = shift;
    while ( my ( $key, $value ) = each %$hash ) {
        if ( 'HASH' eq ref $value ) {
            iterate_hash( $value);
        }
        else {
            #convert 
            if($key =~ m/\./){
                delete ( $hash->{$key} );
                $key =~ s/\./_pnt_/g;
                $hash->{$key} = $value;
                #DEBUG "new value: [".$hash->{$key}."]";
            }
        }
    }
}

sub validate_doc_data {
    my ($data) = @_;
    $data->{extoptions}->{sessionstarttime} =
      int( $data->{extoptions}->{sessionstarttime} );

    # Forcing id to be string value
    #$data->{id} = "$data->{id}";
    iterate_hash($data)
}

sub post_yaml_doc {
    my ( $db, $path ) = @_;
    my ( $name, $basedir, $suffix ) = fileparse( $path, ".yaml" );

    #INFO "Posting document: $name";
    my $yaml_data = YAML::Syck::LoadFile($path);
    validate_doc_data($yaml_data);

    #my $json   = to_json( $yaml_data, { ascii => 1, pretty => 1 } );

    #print Dumper $yaml_data;
    $db ->${COLLECTION}->insert($yaml_data);    #,safe=>1);

    my $err = $db->last_error();
    #INFO "Last error". Dumper $err;

    #TODO atach files

    #INFO "Added document [$doc->{id}]";
}

sub post_command {
    my ( $start_folder, @params ) = @_;

    my $test_results_db = opendb();
    my @yamls;
    find(
        sub {
            push( @yamls, $File::Find::name )
              if (/\.yaml$/);
        },
        $start_folder
    );

    my $item  = 0;
    my $count = scalar @yamls;
    for my $yaml_doc (@yamls) {
        post_yaml_doc( $test_results_db, $yaml_doc );
        $item += 1;
        INFO int( ( $item * 100 ) / $count ), "% processed\n";
    }
}

############################## main

my $dryrun;
GetOptions( "dryrun|dry" => \$dryrun );
my $command = shift @ARGV;
if ( defined( $COMMAND_MAP{$command} ) ) {
    DEBUG "Command: $COMMAND_MAP{$command}";
    &{ $COMMAND_MAP{$command} }(@ARGV);
}
else {
    ERROR "Uknown command '$command'";
    exit 1;
}

