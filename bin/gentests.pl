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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

gentests.pl

=head1 SYNOPSIS

 gentests.pl --testds <directory> --groupname <groupname> --script <path to script>
 --tmpl <path to template> --fw <lustre|ltp>

=head1 DESCRIPTION

The program generates Xperior test descriptor based on external frameworks
scripts and templates (not ready  for LTP, TBD).

On first step  list of tests, which are defined in test framework script
via parsing this script,  is generated .

On second step test group and test options are collected from template and applied
for found tests  from script.

Template is partially filled test descriptor especially for test which needs specific
parameters, .e.g. long timeout.

=head1 OPTIONS

=over 2

=item --testds

Path to directory where store new file

=item --groupname

Name of test group for new tests

=item --script

Path to target test file, e.g. sanity.sh

=item --tmpl

Path to template for test group, e.g. previously customized test decscriptor.

=item --fw

Define which which type of script parsing should be used. Now are
supported B<lustre> (for lustre test-framework.sh based tests) and
B<ltp> for LTP tests.

=item --help

Print this message

=item --man

Help in man way

=back

=cut

use strict;
use warnings;

use English;
use File::Basename;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use YAML qw "Bless LoadFile Load Dump DumpFile";
use Carp;
use Pod::Usage;
use Cwd;

my $XPERIORBASEDIR;
BEGIN {

    $XPERIORBASEDIR = dirname(Cwd::abs_path($PROGRAM_NAME));
    push @INC, "$XPERIORBASEDIR/../lib";

};
use Compat::LustreTests;
use Compat::LTPTests;
Log::Log4perl->easy_init( { level => $DEBUG } );
my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my ($testds, $groupname,  $script, $tmpl, $fw, $helpflag, $manflag,);

GetOptions(
    "testds:s"     => \$testds,
    "groupname:s"  => \$groupname,
    "script:s"     => \$script,
    "tmpl:s"       => \$tmpl,
    "fw:s"         => \$fw,
    "help!"        => \$helpflag,
    "man!"         => \$manflag,
    );

pod2usage( -verbose => 1 ) if ( ($helpflag) || ($nopts) );

pod2usage( -verbose => 2 ) if ($manflag);

my $content;
if($fw eq 'ltp'){
    #TODO implement template usage for ltp
    $content = newLTPSuite( 'groupname'=> $groupname, 'cmdfile' => $script);
}elsif($fw eq 'lustre'){
    $content = Compat::LustreTests::newSuite(
                            name    => $groupname, 
                            script  => $script,
                            default => $tmpl);
}else{
    confess "Support for framework [$fw] is not implemeted"; 
}

$YAML::Stringify = 1;
my $file = "$testds/${groupname}_tests.yaml";
open REP, "> $file" or confess "Cannot create report file [$file]:" . $!;
print REP Dump($content);
close REP;

#DEBUG Dumper $content;

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



Copyright 2014 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

