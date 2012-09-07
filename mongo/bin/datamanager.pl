#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: datamanager.pl
#
#  DESCRIPTION: Sample script for view/get information from 
#               mongo xperior database
#
#       AUTHOR: ryg 
# ORGANIZATION: Xyratex
#      CREATED: 07/25/2012 11:04:48 PM
#===============================================================================

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case );
use File::Basename;
use English;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use XpMongo qw($dbname $collection $host opendb);


my $helpmessage = <<"__HELP__";

Xperior's MongoDB Upload Results Tool

Usage:
    datamanager.pl  [<parameters>] 

Connection:
    --host       ( -H )  - host where database is up on default port ('localhost' if not set)
    --database   ( -D )  - Mongo databse name ('$dbname' if not set)
    --collection ( -C )  - Mongo collection name ('$collection' if not set)

Options:
    --did               - xperior result mongo document id  
    --aid               - mongo grid fs document id

Actions:
    --help       ( -h )  - help (default action)
    --listatt            - list atrributes


__HELP__

sub help {
    my ($target) = @_;
    print $helpmessage;
    return;
}

sub isSet {
    my $var  = shift;
    if((defined( $var)) and ($var ne '')){
        return 1;
    }
    return 0;
}



my ( $help, $listattach, $did, $aid );

GetOptions(
    "database|D:s"   => \$dbname,
    "collection|C:s" => \$collection,
    "host|H:s"       => \$host,

    "help|h"       => \$help,
    "listatt"      => \$listattach,
 
    "did:s"   => \$did,
    "aid:s"   => \$aid,

);

DEBUG "Databse    = $dbname ";
DEBUG "Collection = $collection";
DEBUG "Host       = $host";

if ( not(isSet ($help) or isSet($listattach))) {
    ERROR "No action set";
    help;
    exit 1;
}
if ( defined $help ) {
    help;
}elsif ( isSet($listattach) ) {
    if ( (not isSet($did)) and (not isSet($aid)) ) {
        ERROR "Neither document id nor attachemnt id  set!";
        help;
        exit 1;
    }
    if ( (isSet($did)) and (isSet($aid)) ) {
        ERROR "Both document id [$did] and attachemnt [$aid] set,".
              "please select only one!";
        help;
        exit 1;
    }

    if(isSet($did)){
        DEBUG "List attachements for document id [$did]";
        my $db = opendb();
        my $cursor = $db ->${collection}->find( 
                { _id => 
                    MongoDB::OID->new(value => $did) } );
        my $document = $cursor->next;
        #DEBUG Dumper $document;
        #DEBUG $document->{'_id'};
        if(defined($document)){
            INFO "Document found, listing attachemnts";
            if(defined($document->{'attachments_ids'})){
                INFO "Found [". 
                    scalar(@{$document->{'attachments_ids'}}) .
                    "] attachements";
                
                my $grid = $db->get_gridfs;
                foreach my $aid ( @{$document->{'attachments_ids'}}){
                    my $file = $grid->get($aid);
                    INFO "------------------------------------------";
                    INFO "File id     : ".$file->info->{'_id'};
                    INFO "File name   : ".$file->info->{'filename'};
                    INFO "File length : ".$file->info->{'length'};
                }
            }else{
                ERROR "No attachement found for document [$did]";
            }

        }else{
            ERROR "No document found for id [$did]";
        }
    }elsif( isSet($aid)){
        DEBUG "Show attachement information";
        my $db = opendb();
        my $grid = $db->get_gridfs;
        my $file = $grid->get(
                MongoDB::OID->new(value => $aid));
        if(defined($file)){
            INFO "Info struct is:\n". Dumper $file->info; 
        }else{
            ERROR "Cannot find attachement [$aid]";
        }
    }
}




