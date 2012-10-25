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

remove.pl

=head1 DESCRIPTION

Remove xperior test run from  mongodb

=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use XpMongo qw($dbname $collection $host  remove_by_field);


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
    --branch             - branch id
    --jenkinsbuildit     - TODO


__HELP__

sub help {
    my ($target) = @_;
    print $helpmessage;
    return;
}

############################## main

my ( $dryrun, $help, $post, $sessionstarttime, $branch );

GetOptions(
    "dry|n"          => \$dryrun,
    "database|D:s"   => \$dbname,
    "collection|C:s" => \$collection,
    "host|H:s"       => \$host,

    "sessionstarttime:i"  => \$sessionstarttime,
    "branch:s"            => \$branch,

    "help|h" => \$help,
);

INFO "Dry mode enbaled !"
        if defined $dryrun;
INFO "Sessionstarttime is set to : [$sessionstarttime] "
        if defined $sessionstarttime;

DEBUG "Databse    = $dbname ";
DEBUG "Collection = $collection";
DEBUG "Host       = $host";

if (     ( not defined $help )
     and (not defined $sessionstarttime)
     and (not defined $branch) )  {
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
    remove_by_field($dryrun,'extoptions.sessionstarttime',
                                            $sessionstarttime);
}elsif ( defined($branch)){
    DEBUG "Removing by session time";
    remove_by_field($dryrun, 'extoptions.branch',
                                            $branch);
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


