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

checkyaml.pl

=head1 SYNOPSIS

    checkyaml.pl --dir=<directory> [--failonundef]

=head1 DESCRIPTION

Tool for check yaml files correctness. Based on L<Data::Rx library|http://rx.codesimply.com>,
schemas are getting from Xperior C<data> dir

=head1 OPTIONS


=over 12


=item --dir

Directory where placed target yaml files. These files will NOT be changed.

=item --failonundef
If set program exit with error code  9 if found yaml without field 'schema' or cannot find file defined in 'schema' field.

=back

=head1 EXIT CODES

=over 12

=item  0

All is ok

=item  9

No 'schema' field found in yaml document and option --failonundef set

=item 8

Data doesn't fit to schema

=back

=cut

##################### main
use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );
use Pod::Usage;
use File::Basename;
use English;
use Cwd qw(abs_path);

my $XPERIORBASEDIR;
BEGIN {

    $XPERIORBASEDIR = dirname(Cwd::abs_path($PROGRAM_NAME));
    push @INC, "$XPERIORBASEDIR/../lib";

};

use Xperior::CheckConfig;
use Error qw(:try);
use Xperior::Xception;

$| = 1;

#process parameters
my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my ( $dir, $fuflag, $helpflag, $manflag );
GetOptions(
    "dir:s"       => \$dir,
    "failonundef!" => \$fuflag,
    "help!"        => \$helpflag,
    "man!"         => \$manflag,
);
pod2usage( -verbose => 1 ) if ( ($helpflag) || ($nopts) );

pod2usage( -verbose => 2 ) if ($manflag);

if ( ( not defined $dir ) || ( $dir eq '' ) ) {
    print "No directory with YAML files set!\n";
    pod2usage( -verbose => 1 );
    exit 1;
}
try {
    checkDir( $dir, $fuflag );
}
catch NoSchemaException with {
    exit 9;
}
catch CannotPassSchemaException with {
    exit 8;
}
catch Error with {
    ERROR "Unknow failure";
    exit 10;
}
finally {};

INFO "Completed!";

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


