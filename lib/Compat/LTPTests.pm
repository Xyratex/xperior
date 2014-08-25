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

Compat::LTPTests - provides functionality for generating Xperior data files

=cut

package Compat::LTPTests;
use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::Basename;
use File::Slurp;
use English;
use Carp;
use Cwd;
use YAML qw "Bless LoadFile Load Dump DumpFile";
our @ISA;
our @EXPORT;

BEGIN {
    @ISA = ("Exporter");
    @EXPORT = qw(&newLTPSuite);
    Log::Log4perl->easy_init( { level => $DEBUG } );
}

=head2 newSuite

Compose new suite content from given shell script

=over

=item script (mandatory)

Test suite shell script

=item default (optional)

Default suite yaml file path

=item name (optional)

Suite name, aka groupname. If omitted, the script name is taken.

=back

Example:

  my $scriptFile   = "${lustreTestsDir}/${suiteName}.sh";
  my $defaultSuite = "${predefinedDir}/${suiteName}_tests.yaml",

  my $suite = newSuite( script  => $scriptFile,
                        default => $defaultSuite,
                        name    => $suiteName );

  DumpFile("${outputDir}/${suiteName}_tests.yaml", $suite);

=cut

sub newLTPSuite {
    my (%param) = @_;
    my $groupname = $param{groupname}  || confess "'groupname' is not set";
    my $cmdfile   = $param{cmdfile}  || confess "'cmdfile' is not set";
    my @tests = _findSuiteTests($cmdfile);
    my $content = {
        groupname   => $groupname,
        description => "LTP $groupname tests",
        reference   => 'http://ltp.sourceforge.net/',
        executor    => 'Xperior::Executor::LTPTests',
        timeout     => '60',
        Tests       => \@tests,
    };
    return $content;
}


# Parses suite script and returns array of tests
sub _findSuiteTests {
    my ($script) = @_;
    my @tests;
    open( SCRIPT, "<$script" ) or confess "Cannot read file $script";
    while (<SCRIPT>) {
        my $line = $_;
        chomp $line;
        if ( $line =~/^([\w\d]+)\s+(.*)$/)
        {
            push @tests, { id => $1, cmd => $line };
            DEBUG "Found test $1: $line";
        }
    }
    close SCRIPT;
    INFO "Found tests: ", scalar @tests;
    return @tests;
}

1;

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

=head1 AUTHORS

Roman Grigoryev<Roman_Grigoryev@xyratex.com>,

=cut

