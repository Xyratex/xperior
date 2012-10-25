#!/usr/bin/perl
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

upload.pl

=cut

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


