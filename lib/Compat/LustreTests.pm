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
use YAML qw "Bless LoadFile Load Dump";
my $XPERIORBINDIR;
our @ISA;
our @EXPORT;

BEGIN {
    @ISA           = ("Exporter");
    @EXPORT        = qw(&writeGeneratedTagsFile &writeGeneratedTestSuiteFile &getGeneratedTestSuite);
    $XPERIORBINDIR = dirname( Cwd::abs_path($PROGRAM_NAME) );
    push @INC, "$XPERIORBINDIR/../lib";
    Log::Log4perl->easy_init( { level => $DEBUG } );

}
use constant LUSTRETESTS => '/usr/lib64/lustre/tests';

=item  writeTestSuiteFile($testdir, $testsuite, $predefineddir, $sourcedir)
    $testdir       - where store new test descriptor
    
    $testsuite     - name of test suite (test group) whose descriptor will                    be generated
    
    $predefineddir - directory, where stored test descriptor, values from                     whose will be added to new test suite descriptor

    $sourcedir     - where original lustre test scripts are

=cut

sub writeGeneratedTestSuiteFile {
    my ($testdir, $tsname, $pdir, $sdir ) = @_;
    my $yaml = getGeneratedTestSuite($tsname, $pdir, $sdir);
    $YAML::Stringify = 1;
    my $file = "$testdir/${tsname}_tests.yaml";
    open REP, "> $file" or confess "Cannot open report file:" . $!;
    print REP Dump($yaml);
    close REP;
}

sub getGeneratedTestSuite{
    my ($tsname, $pdir, $sdir ) = @_;
    my $script = "$sdir/$tsname.sh";

    unless ( -e "$script" ) {
        confess "Cannot open test script [$script]";
    }
    my $ts = _generateTestSuite( $tsname, $script );
    $ts = _mergeWithPreconfig( $ts, $tsname, $pdir );
    return $ts;
}

sub _mergeWithPreconfig {
    my ( $ts, $tsname, $pdir ) = @_;
    my $pcfgscr = "$pdir/${tsname}_tests.yaml";
    unless ( -e $pcfgscr ) {
        WARN "Cannot open file [$pcfgscr], no merge done";
        return $ts;
    }
    my $pcfg = LoadFile($pcfgscr);

    foreach my $key ( keys %{$pcfg} ) {
        if ( $key eq 'Tests' ) {
            foreach my $t ( @{ $pcfg->{$key} } ) {
                my $tid = $t->{'id'};
                DEBUG "Check test $tid description";

                my $nto = undef;
                foreach my $ntk ( @{ $ts->{$key} } ) {
                    next unless ( $ntk->{'id'} eq $tid );
                    $nto = $ntk;
                    last;
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
            unless ( defined( $ts->{$key} ) ) {
                $ts->{$key} = $pcfg->{$key};
            }
        }
    }
    return $ts;
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
    my ($testdir ) = @_;
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

