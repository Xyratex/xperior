#!/usr/bin/perl 
#===============================================================================

use strict;
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
use Getopt::Long qw(:config no_ignore_case );

use YAML::Syck;
local $YAML::Syck::ImplicitTyping = 1;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );

my $dbname     = "lustre";   # default name which used in tests
my $collection = "tresults"; # default db which used in tests
my $host       = "localhost";

my $helpmessage = <<"__HELP__";

Xperiors MongoDB Upload Results Tool

Usage:
    upload-results  [<parameters>] [<actions>]

Options:
    --dry     ( -n )  - do all witout real upload to database
    --host       ( -H )  - host where database is up on default port ('localhost' if not set)
    --database   ( -D )  - Mongo databse name ('$dbname' if not set)
    --collection ( -C )  - Mongo collection name ('$collection' if not set)
    --folder     ( -f )  - folder with results, obligatory for --post. 
Actions
    --help       ( -h )  - help (default action)
    --post       ( -p )  - Post document from folder (see --folder opton)


__HELP__

sub help {
    my ($target) = @_;
    print $helpmessage;

}

sub opendb {
    INFO "Connecting to MongoDB";
    my $conn = MongoDB::Connection->new( host => $host )
      or die "The server cannot be reached";
    my $db = $conn ->${dbname};
    my $stat = $db->run_command( { serverStatus => -1 } );
    INFO "MongoDB ver: " . $stat->{version} . "\n";

    #my $collection = $db->lustre;
    return $db;
}

sub iterate_hash {
    my $hash = shift;
    while ( my ( $key, $value ) = each %$hash ) {
        if ( 'HASH' eq ref $value ) {
            iterate_hash($value);
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
}

sub validate_doc_data {
    my ($data) = @_;
    $data->{extoptions}->{sessionstarttime} =
      int( $data->{extoptions}->{sessionstarttime} );

    # Forcing id to be string value
    #$data->{id} = "$data->{id}";
    iterate_hash($data);
}

sub post_yaml_doc {
    my ( $db, $path ) = @_;
    my ( $name, $basedir, $suffix ) = fileparse( $path, ".yaml" );

    #INFO "Posting document: $name";
    my $yaml_data = YAML::Syck::LoadFile($path);
    validate_doc_data($yaml_data);


    $db ->${collection}->insert($yaml_data);    #,safe=>1);

    my $err = $db->last_error();

    #INFO "Last error". Dumper $err;
    #TODO atach files
    #INFO "Added document [$doc->{id}]";
}

sub post {
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

my ( $dryrun, $help, $post, $folder );

GetOptions(
    "dry|n"          => \$dryrun,
    "database|D:s"   => \$dbname,
    "collection|C:s" => \$collection,
    "host|H:s"       => \$host,
    "folder|f:s"     => \$folder,

    "help|h" => \$help,
    "post|p" => \$post
);


INFO "Dry mode enbaled !" if defined $dryrun;
INFO "Folde is set to : [$folder] " if defined $folder;
DEBUG "Databse    = $dbname ";
DEBUG "Collection = $collection";
DEBUG "Host       = $host";


if ( ( not defined $help ) && ( not defined $post ) ) {
    ERROR "No action set";
    help;
    exit 1;
}

if ( defined $help ) {
    help;
}
elsif ( defined($post) ) {
    unless ( defined $folder ) {
        ERROR "No folder with yaml results set!";
        help;
        exit 1;
    }

    DEBUG "Do post";
    post($folder);
}

