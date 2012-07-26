#!/usr/bin/perl 
#======================================================================

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case );
use File::Basename;
use English;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use XpMongo qw($dbname $collection $host post);

my $helpmessage = <<"__HELP__";

Xperior's MongoDB Upload Results Tool

Usage:
    upload  [<parameters>] [<actions>]

Options:
    --dry        ( -n )  - do all witout real upload to database
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
    return;
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

INFO "Dry mode enbaled !"           if defined $dryrun;
INFO "Folder is set to : [$folder] " if defined $folder;
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
    if ( (!(defined $folder)) or ( $folder eq '') ) {
        ERROR "No folder with yaml results set!";
        help;
        exit 1;
    }

    DEBUG "Do post";
    post($folder);
}

