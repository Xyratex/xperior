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
# Author: Kyrylo Shatskyy<Kyrylo_Shatskyy@xyratex.com>
#

=pod

=head1 NAME

Compat::LustreTests - provides functionality for generating Xperior data files

=cut

package Compat::LustreTests;
use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::Basename;
use File::Slurp;
use English;
use Carp;
use Cwd;
use YAML qw "Bless LoadFile Load Dump DumpFile";
my $XPERIORBINDIR;
our @ISA;
our @EXPORT;

=head1 DESCRIPTION

Module provides functionality for generating Xperior
L<test descriptors|XperiorUserGuide/"Test descriptor"> and Xperior exclude
list based on Lustre test scripts.

Sample code how use it:

    use Compat::LustreTests
    writeGeneratedTestSuiteFile( "$wd/workdir", $suite,'testds', 'tests' );

=cut

BEGIN {
    @ISA = ("Exporter");
    @EXPORT = qw(
                    &newSuite &newExcludeList
                    &writeGeneratedTagsFile &writeGeneratedTestSuiteFile &writeTestSuiteExclude  
                    &getGeneratedTestSuite &getGeneratedTestSuiteExclude
                );
    $XPERIORBINDIR = dirname( Cwd::abs_path($PROGRAM_NAME) );
    push @INC, "$XPERIORBINDIR/../lib";
    Log::Log4perl->easy_init( { level => $DEBUG } );

}

use constant LUSTRETESTS => '/usr/lib64/lustre/tests';

=head2 writeTestSuiteExclude ($outputDir, $suiteName, $predefinedList, $lustreTestsDir)

Saving Xperior exclude list for test-framework.sh based suite.

Only test from  B<ALWAYS_EXCEPT> save to exclude list.

    $outputDir        - where store new exclude list

    $suiteName      - name of test suite (test group) which descriptor will
                     be generated

    $predefinedList - predefined exclude list file, which will be merged with data from suites

    $lustreTestsDir      - where original lustre test scripts are

=cut

sub writeTestSuiteExclude {
    my ( $outputDir, $suiteName, $predefinedList, $lustreTestsDir ) = @_;
    my $excludelist = getGeneratedTestSuiteExclude( $suiteName, $predefinedList,
        $lustreTestsDir );
    open( EX, " > $outputDir/${suiteName}_exclude.list" )
      or confess "Cannot create exclude list: " . $!;
    print EX $excludelist;
    close EX;
}    ## --- end sub writeTestSuiteExclude

=head2  writeTestSuiteFile($outputDir, $suiteName, $predefinedDir, $lustreTestsDir)

Saving Xperior test descriptor for test-framework.sh based suite.

Only tests which start from B<run_test> or
B<run_test_with_stat> save to test descriptor.

    $outputDir        - where store new test descriptor

    $suiteName        - name of test suite (test group) whose descriptor will
                     be generated

    $predefinedDir   - directory, where stored test descriptor, values from
                    whose will be added to new test suite descriptor

    $lustreTestsDir   - where original lustre test scripts are

=cut

sub writeGeneratedTestSuiteFile {
    my ( $outputDir, $suiteName, $predefinedDir, $lustreTestsDir ) = @_;
    my $yaml =
      getGeneratedTestSuite( $suiteName, $predefinedDir, $lustreTestsDir );
    $YAML::Stringify = 1;
    my $file = "$outputDir/${suiteName}_tests.yaml";
    open REP, "> $file" or confess "Cannot create report file:" . $!;
    print REP Dump($yaml);
    close REP;
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

sub newSuite {
    my (%param) = @_;
    my $script  = $param{script}   || confess "Undefined 'script' parameter";
    my $name    = $param{name}     || basename ($script, ".sh");
    my $default = $param{default};
    my @tests = _findSuiteTests($script);
    my $content = {
        groupname   => $name,
        description => "Lustre $name tests",
        reference   => "http://wiki.lustre.org/index.php/Testing_Lustre_Code",
        Tests       => \@tests,
    };
    if (-f $default) {
        DEBUG "Loading default suite: $default";
        $content = _mergeSuites($content, LoadFile($default));
    }
    return $content;
}

sub getGeneratedTestSuite {
    my ( $tsname, $pdir, $sdir ) = @_;
    my $script = "$sdir/$tsname.sh";

    unless ( -e "$script" ) {
        confess "Cannot open test script [$script]";
    }
    my $ts = _generateTestSuite( $tsname, $script );
    $ts = _mergeWithPreconfig( $ts, $tsname, $pdir );
    return $ts;
}

sub getGeneratedTestSuiteExclude {
    my ( $tsname, $predefinedlist, $sdir ) = @_;
    my $script = "$sdir/$tsname.sh";

    unless ( -e "$script" ) {
        confess "Cannot open test script [$script]";
    }
    my $excludeTests = _generateTestSuiteExclude( $tsname, $script );
    my $exclist =
      _mergeWithPredefinedExclude( $excludeTests, $tsname, $predefinedlist );
    return $exclist;
}    ## --- end sub getGeneratedTestSuiteExclude

sub _generateTestSuiteExclude {
    my ( $tsname, $script ) = @_;
    my @excluded = map { "$tsname/$_" } _findSuiteExclusions($script);
    return \@excluded;
}    ## --- end sub _generateTestSuiteExclude

=head2 _findSuiteExclusions <script>

Returns array of excluded tests found in the suite shell script file

Usage:
   my @exclude_list = map { "sanity/$_" } _findSuiteExclusions("sanity.sh");
   write_file("exclude.list", @exclude_list);

=cut

sub _findSuiteExclusions {
    my ($script) = @_;
    INFO "Reading $script";
    my @items;
    open( SCRIPT, "<$script" ) or confess "Cannot read file $script";
    DEBUG "Read file [$script]";
    while (<SCRIPT>) {
        my $str = $_;
        chomp $str;
        if ( $str =~ m/ALWAYS_EXCEPT.*=.*\"(.+)\"/ ) {
            DEBUG "ALWAYS_EXCEPT found in string [$str]";
            my @splitted = split /\s+/, $1;
            foreach my $t (@splitted) {
                if ( $t =~ m/\d+\w*/ ) {
                    push @items, $t;
                    DEBUG "Found [$t]";
                }
            }
            last;
        }
    }
    close SCRIPT;
    INFO "Found excluded tests: ", scalar @items;
    return @items;
}

=head2 newExcludeList

Returns exclude list generated from suite shell script

=over

=item script (mandatory)

Test suite shell script

=item name (optional)

Suite name used for exclusion rules.

=item default (optional)

Default suite yaml file path

=back

Usage:
    
    my @exclude_list 
        = map { newExcludeList(script => "$_.sh", name => $_  } @tests;
    write_file("exclude.list", @exclude_list);

=cut

sub newExcludeList {
    my (%param) = @_;
    my $script  = $param{script}   || confess "Undefined 'script' parameter";
    my $name    = $param{name}     || basename ($script, ".sh");
    my $default = $param{default};
    my @list    = map { "$name/$_" } _findSuiteExclusions($script);
    if ($default and -f $default) {
        my @defaultList = read_file($default);
        push @list, @defaultList;
    }
    return @list;
}

sub _mergeWithPredefinedExclude {
    my ( $excludedtests_arr, $tsname, $predefinedlist ) = @_;

    my $excludedtests = join( "\n", @{$excludedtests_arr} );
    my $pre = '';
    open PF, '<', $predefinedlist
      or confess "failed to open  input file '$predefinedlist' : $!\n";
    while (<PF>) {
        $pre = $pre . $_;
    }
    close PF
      or warn "failed to close input file '$predefinedlist' : $!\n";

    my $res = << "MERGED"
#########################################################
### test from suite '$tsname'
$excludedtests

#########################################################
### add non-tests excluded tests from
$pre

MERGED
      ;

    return $res;
}    ## --- end sub _mergeWithPreconfigExclude

sub _mergeWithPreconfig {
    my ( $tests, $suiteName, $lustreTestsDir ) = @_;
    my $pcfgscr = "$lustreTestsDir/${suiteName}_tests.yaml";
    unless ( -e $pcfgscr ) {
        WARN "Cannot open file [$pcfgscr], no merge done";
        return $tests;
    }
    my $pcfg = LoadFile($pcfgscr);
    $tests = _mergeSuites($tests, $pcfg);
    return $tests;
}

sub _mergeSuites {
    my ( $target, $default ) = @_;

    foreach my $key ( keys %{$default} ) {
        if ( $key eq 'Tests' ) {
            foreach my $test ( @{ $default->{$key} } ) {
                my $tid = $test->{'id'};
                DEBUG "Check test $tid description";

                my $nto = undef;
                foreach my $ntk ( @{ $target->{$key} } ) {
                    if ( $ntk->{'id'} eq $tid ) {
                        $nto = $ntk;
                        last;
                    }
                }
                unless ( defined($nto) ) {
                    INFO "Skip preconfigured object for test [$tid]";
                    next;
                }

                foreach my $tk ( keys %{$test} ) {
                    unless ( defined( $nto->{$tk} ) ) {
                        DEBUG "Found unset key {$tk} for test [$tid]";
                        $nto->{$tk} = $test->{$tk};
                    }
                }
            }
        }
        else {
            unless ( defined( $target->{$key} ) ) {
                $target->{$key} = $default->{$key};
            }
        }
    }
    return $target;
}

#TODO create tests for it
sub _generateTestSuite {
    my ( $suitename, $script ) = @_;
    INFO "Reading $script";
    my $content = {
        groupname   => $suitename,
        description => "Lustre $suitename tests",
        reference   => "http://wiki.lustre.org/index.php/Testing_Lustre_Code",
        Tests       => [],
    };
    @{$content->{Tests}} = _findSuiteTests($script);
    return $content;
}

# Parses suite script and returns array of tests
sub _findSuiteTests {
    my ($script) = @_;
    my @tests;
    open( SCRIPT, "<$script" ) or confess "Cannot read file $script";
    while (<SCRIPT>) {
        if ( $_ =~
/^(run_test|run_test_with_stat)\s+([\d\w]+)\s+\"([^\"]+)\"\s*$/
          )
        {
            push @tests, { id => $2 };
            DEBUG "Found test $2: $3";
        }
    }
    close SCRIPT;
    INFO "Found tests: ", scalar @tests;
    return @tests;
}

#TODO write tests for it
sub writeGeneratedTagsFile {
    my ($testdir) = @_;
    my $yaml = _getTags();
    $YAML::Stringify = 1;
    my $file = "$testdir/tags.yaml";
    open REP, "> $file" or confess "Cannot open report file:" . $!;
    print REP Dump($yaml);
    close REP;

}

sub _getTags {

    #TODO read it from file
    return {
        tags => [
            {
                id   => 'performance.io',
                name => 'I/O Performance',
                description =>
'typical clustered filesystem performance benchmarks. Test subtypes: shared-single-file, file-per-process'
            },
            {
                id   => 'performance.md',
                name => 'Metadata performance',
                description =>
'Test subtypes by operation and pattern (eg: directory-per-client create, shared directory create)'
            },
        ]
    };
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHORS

Roman Grigoryev<Roman_Grigoryev@xyratex.com>,
Kyrylo Shatskyy<Kyrylo_Shatskyy@xyratex.com>

=cut

