#
#===============================================================================
#
#         FILE:  LustreTests.pm
#
#  DESCRIPTION:  Set of functions to work with old bash lustre test
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  05/07/2012 07:34:30 PM
#===============================================================================
package Compat::LustreTests;
use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::Basename;
use English;
use Carp;
use Cwd;
use YAML qw "Bless LoadFile Load Dump DumpFile";
my $XPERIORBINDIR;
our @ISA;
our @EXPORT;

=pod

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
    @EXPORT =
      qw(&writeGeneratedTagsFile &writeGeneratedTestSuiteFile &writeTestSuiteExclude  &getGeneratedTestSuite &getGeneratedTestSuiteExclude);
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
    INFO "Reading $script";
    my @excluded;
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
                    push @excluded, "$tsname/$t";
                    DEBUG "Found [$tsname: $t]";
                }
            }
            last;
        }
    }
    close SCRIPT;
    INFO "Found excluded tests: ", scalar @excluded;
    return \@excluded;
}    ## --- end sub _generateTestSuiteExclude

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

    foreach my $key ( keys %{$pcfg} ) {
        if ( $key eq 'Tests' ) {
            foreach my $t ( @{ $pcfg->{$key} } ) {
                my $tid = $t->{'id'};
                DEBUG "Check test $tid description";

                my $nto = undef;
                foreach my $ntk ( @{ $tests->{$key} } ) {
                    if ( $ntk->{'id'} eq $tid ) {
                        $nto = $ntk;
                        last;
                    }
                }
                unless ( defined($nto) ) {
                    INFO "Skip preconfigured object for test [$tid]";
                    next;
                }

                foreach my $tk ( keys %{$t} ) {
                    unless ( defined( $nto->{$tk} ) ) {
                        DEBUG "Found unset key {$tk} for test [$tid]";
                        $nto->{$tk} = $t->{$tk};
                    }
                }
            }
        }
        else {
            unless ( defined( $tests->{$key} ) ) {
                $tests->{$key} = $pcfg->{$key};
            }
        }
    }
    return $tests;
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

    open( SCRIPT, "<$script" ) or confess "Cannot read file $script";
    while (<SCRIPT>) {
        if ( $_ =~
/^(run_test|run_test_with_stat)\s+([0-9]+[A-Za-z]*)\s+\"([^\"]+)\"\s*$/
          )
        {
            push @{ $content->{Tests} }, { id => $2 };
            DEBUG "Found '$suitename' test $2: $3";
        }
    }
    close SCRIPT;
    INFO "Found tests: ", scalar @{ $content->{Tests} };
    return $content;
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

