#
#===============================================================================
#
#         FILE:  XTests::Core.pm
#
#  DESCRIPTION:  Main module for XTests harness
#
#       AUTHOR:   ryg
#      COMPANY:  Xyratex
#      CREATED:  09/05/2011 03:23:42 PM
#===============================================================================

package XTests::Core;
use Log::Log4perl qw(:easy);
use YAML qw "Bless LoadFile Load";
use Data::Dumper;
use File::Find;
use Moose;

#use MooseX::Storage;
use Carp qw( confess cluck );
use File::Path;
use File::chdir;
use Module::Load;

use XTests::Test;
use XTests::TestEnvironment;
use XTests::Utils;

our $VERSION = "0.0.1";

has 'options'    => ( is => 'rw' );
has 'tests'      => ( is => 'rw' );    # isa => 'ArrayRef[]', );
has 'testgroups' => ( is => 'rw' );
has 'env'        => ( is => 'rw' );

sub createExecutor {
    my ( $self, $es ) = @_;
    DEBUG "Loading module [$es]";
    load $es;
    return $es->new;
}

sub runtest {
    DEBUG "XTests::Core::runtest";
    my ( $self, $test ) = @_;
    DEBUG "Starting tests " . $test->getParam('id');

    #DEBUG "Test is:". Dumper $test;
    my $executor = $self->createExecutor( $test->getParam('executor') );
    $executor->init( $test, $self->options, $self->env );
    $executor->execute;
    $executor->report();
    return $executor->result_code;
}

sub run {
    my $self    = shift;
    my $options = shift;
    $self->{'options'} = $options;
    DEBUG "Start framework";
    my $tags = $self->loadTags;
    $self->tests( $self->loadTests );
    $self->env( $self->loadEnvCfg );
    if ( $self->env->checkEnv < 0 ) {
        WARN "Found problesm while testing configuration";
        exit(19);
    }

    #$self->env->getNodesInfo;

    #TODO load exclude list

    #TODO check tests applicability there

    #start testing
    my @tests;
    my @rts = @{ $self->{'tests'} };
    my %targs;
    my @includeonly = @{ $self->options->{'includeonly'} };
    my $excludelist = undef;
    $excludelist = parseIEFile( $self->options->{'excludelist'} )
      if defined $self->options->{'excludelist'};
    my $executedtests;

    if ( $self->options->{'continue'} ) {
        $executedtests = getExecutedTestsFromWD( $self->options->{'workdir'} );
    }

    #going over all loaded tests
    my $snum = 0;
    my $enum = 0;
    foreach my $test (@rts) {

        #DEBUG "Test = ".Dumper $test;

        ##filtering
        my $filtered = 0;

        #if includeonly set ignore all other filtering options
        if ( ( scalar @includeonly ) > 0 ) {
            $filtered = 1;
            foreach my $iodescr (@includeonly) {
                $filtered = 0
                  if (
                    compareIE( $iodescr,
                        $test->getGroupName . '/' . $test->getName ) > 0
                  );
            }
        }
        else {

            #skip tags
            foreach my $tt ( @{ $test->getTags } ) {
                foreach my $t ( @{ $self->options->{'skiptags'} } ) {
                    $filtered++ if $t eq $tt;
                }
            }

            # skip exclude list
            if ( defined $excludelist ) {
                foreach my $tmpl (@$excludelist) {
                    $filtered = 1
                      if (
                        compareIE( $tmpl,
                            $test->getGroupName . '/' . $test->getName ) > 0
                      );
                }
            }

        }

        #skip already executed for --continue
        foreach my $et (@$executedtests) {
            $filtered = 1
              if (
                compareIE( $et,
                    $test->getGroupName . '/' . $test->getName . '.yaml' ) == 1
              );
        }

        if ($filtered) {
            $snum++;
            next;
        }
        WARN "Starting test execution";
        my $a = $self->options->{'action'};
        if ( $a eq 'run' ) {
            my $res = $self->runtest($test);
            WARN 'TEST '
              . $test->getName
              . ' STATUS: '
              . $test->results->{'status'};
            $enum++;
            if ( $res != 0 ) {

                #test failed, do env check
                my $cer = $self->{'env'}->checkEnv;
                if ( $cer < 0 ) {
                    WARN
"Found problesm while testing configuration after failed test, exiting";
                    WARN "Executed $enum tests, skipped $snum";
                    exit(10);
                }
                if ( $test->getParam('dangerous') eq 'yes' ) {
                    WARN "Dangerous test failure detected, exiting";
                    WARN "Executed $enum tests, skipped $snum";
                    exit(11);
                }
            }
        }
        elsif ( $a eq 'list' ) {
            print "====================\n";
            print $test->getDescription;
        }
        else {
            confess "Cannot selected action for : $a";
        }
    }
    WARN "Execution completed";
    WARN "Executed $enum tests, skipped $snum";
}

sub loadEnvCfg {
    DEBUG 'XTests::Core->loadEnvCfg';
    my $self = shift;
    my $fn   = shift;
    $fn = 'systemcfg.yaml' unless defined $fn;
    DEBUG "Load env configuration file [ $fn ]";
    my $envcfg = LoadFile($fn) or confess $!;

    #DEBUG Dumper $envcfg;
    my $env = undef;
    $env = XTests::TestEnvironment->new;
    $env->init($envcfg);

    #DEBUG Dumper $env;
    return $env;
}

sub loadTests {
    DEBUG 'XTests::Core->loadTests';
    my $self = shift;
    my @testNames;
    my @tests;
    INFO "Reading tests from dir:[" . $self->{'options'}->{'testdir'} . "]";
    find(
        sub {
            push( @testNames, $File::Find::name )
              if ( $File::Find::name =~ m/tests.yaml/ );
        },
        $self->{'options'}->{'testdir'}
    );

    #DEBUG Dumper @testNames;

    foreach my $fn (@testNames) {
        my $testscfg = $self->loadTestsFile($fn);
        my %groupcfg;
        foreach my $key ( keys %{$testscfg} ) {
            $groupcfg{$key} = $testscfg->{$key}
              if ( $key ne 'Tests' );
        }

        foreach my $testcfg ( @{ $testscfg->{'Tests'} } ) {
            my $test = XTests::Test->new;

            #DEBUG "groupcfg=".Dumper \%groupcfg;
            $test->init( $testcfg, \%groupcfg );
            push @tests, $test;
        }
    }

    #DEBUG 'Load tests result:' . Dumper \@tests;
    return \@tests;
}

sub loadTestsFile {
    my $self = shift;
    my $fn   = shift;
    INFO "Load test file [ $fn ]";
    my $testscfg = LoadFile($fn) or confess $!;

    #DEBUG Dumper $testscfg;
    return $testscfg;
}

sub loadTags {
    DEBUG 'XTests::Core->loadTestSuites';
    my $self = shift;
    my $file = $self->{'options'}->{'testdir'} . '/tags.yaml';
    INFO "Load tag file [ $file ]";
    my $cfg = LoadFile($file) or confess $!;

    #DEBUG Dumper $cfg;
    return $cfg->{'tags'};
}

__PACKAGE__->meta->make_immutable;

