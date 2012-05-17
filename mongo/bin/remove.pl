#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  remove.pl
#
#        USAGE:  ./remove.pl  
#
#  DESCRIPTION: Remove xperior test run from  mongodb
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  05/10/2012 04:11:15 PM
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use XpMongo qw($dbname $collection $host  remove_by_sessionstarttime);


my $helpmessage = <<"__HELP__";

Xperior's MongoDB  Results Removal  Tool

Usage:
    remove  [<parameters>] 

Options:
    --dry        ( -n )  - do all witout real removing to database
    --host       ( -H )  - host where database is up on default port ('localhost' if not set)
    --database   ( -D )  - Mongo databse name ('$dbname' if not set)
    --collection ( -C )  - Mongo collection name ('$collection' if not set)

Removing parameters:
    --sessionstarttime   - epoch of xperior testing start
    --jenkinsbuildit     - TODO


__HELP__

sub help {
    my ($target) = @_;
    print $helpmessage;
    return;
}

############################## main

my ( $dryrun, $help, $post, $sessionstarttime );

GetOptions(
    "dry|n"          => \$dryrun,
    "database|D:s"   => \$dbname,
    "collection|C:s" => \$collection,
    "host|H:s"       => \$host,

    "sessionstarttime:i"     => \$sessionstarttime,

    "help|h" => \$help,
);

INFO "Dry mode enbaled !"           
        if defined $dryrun;
INFO "Sessionstarttime is set to : [$sessionstarttime] " 
        if defined $sessionstarttime;

DEBUG "Databse    = $dbname ";
DEBUG "Collection = $collection";
DEBUG "Host       = $host";

if ( ( not defined $help ) && ( not defined $sessionstarttime ) ) {
    ERROR "No action set";
    help;
    exit 1;
}

if(defined($dryrun)){
    $dryrun=0;
}else{
    $dryrun=1;
}

if ( defined $help ) {
    help;
}
elsif ( defined($sessionstarttime) ) {
    DEBUG "Removing by session time";
    remove_by_sessionstarttime($dryrun, $sessionstarttime);
}




