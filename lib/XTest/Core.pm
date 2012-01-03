#
#===============================================================================
#
#         FILE:  XTest::Core.pm
#
#  DESCRIPTION:  Main module for XTest harness
#
#       AUTHOR:   ryg
#      COMPANY:  Xyratex
#      CREATED:  09/05/2011 03:23:42 PM
#===============================================================================

package XTest::Core;
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

use XTest::Test;
use XTest::TestEnvironment;
use XTest::Utils;

our $VERSION = "0.0.2";

has 'options'    => ( is => 'rw' );
has 'tests'      => ( is => 'rw' );    # isa => 'ArrayRef[]', );
has 'testgroups' => ( is => 'rw' );
has 'env'        => ( is => 'rw' );

sub createExecutor {
    my ( $self, $es, $roles ) = @_;
    DEBUG "Loading module [$es]";
    load $es;
    my $obj = $es->new;
    if ( defined($roles) ) {
        foreach my $role ( split( /\s/, $roles ) ) {
            DEBUG "Applying roles [$role]";

            if ( $role eq 'LustreClientStatus' ) {
                use XTest::Executor::Roles::LustreClientStatus;
                XTest::Executor::Roles::LustreClientStatus->meta->apply($obj);
            }

            if ( $role eq 'StoreSyslog' ) {
                use XTest::Executor::Roles::StoreSyslog;
                XTest::Executor::Roles::StoreSyslog->meta->apply($obj);
            }

            if ( $role eq 'StoreConsole' ) {
                use XTest::Executor::Roles::StoreConsole;
                XTest::Executor::Roles::StoreConsole->meta->apply($obj);
            }

        }
    }
    return $obj;
}

sub runtest {
    DEBUG "XTest::Core::runtest";
    my ( $self, $test ) = @_;
    DEBUG "Starting tests " . $test->getParam('id');

    #DEBUG "Test is:". Dumper $test;
    my $executor = $self->createExecutor( $test->getParam('executor'),
        $test->getParam('roles') );
    $executor->init( $test, $self->options, $self->env );

    #apply ext params to test
    foreach my $param ( @{ $self->options->{'extopt'} } ) {
        if ( $param =~ m/^([\w\d]+)\s*\:(.+)$/ ) {
            $executor->setExtOpt( $1, $2 );
        }
        else {
            DEBUG "Cannot parse parameters[$param]";
        }
    }

    $executor->execute;
    $executor->report();
    $executor->tap() if $self->options->{'tap'};
    return $executor->result_code;
}

sub run {
    my $self    = shift;
    my $options = shift;
    $self->{'options'} = $options;
    DEBUG "Start framework";
    my $tags = $self->loadTags;
    $self->tests( $self->loadTests );
    $self->env( $self->loadEnvCfg( $options->{'configfile'} ) );
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
    my $includelist = undef;

    #DEBUG "Process defined excludelist [".$self->options->{'excludelist'}."]";
    $excludelist = parseIEFile( $self->options->{'excludelist'} )
      if ( ( defined $self->options->{'excludelist'} )
        && ( $self->options->{'excludelist'} ne '' ) );

    $includelist = parseIEFile( $self->options->{'includelist'} )
      if ( ( defined $self->options->{'includelist'} )
        && ( $self->options->{'includelist'} ne '' ) );

    my $executedtests;

    if ( $self->options->{'continue'} ) {
        $executedtests = getExecutedTestsFromWD( $self->options->{'workdir'} );
    }
    DEBUG Dumper $includelist;
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

                #DEBUG "Process defined excludelist [$excludelist]";
                foreach my $tmpl (@$excludelist) {
                    $filtered = 1
                      if (
                        compareIE( $tmpl,
                            $test->getGroupName . '/' . $test->getName ) > 0
                      );
                }
            }

            if ( defined $includelist ) {
                #DEBUG "Process defined excludelist [$includelist]";
                foreach my $it (@$includelist) {
                    $filtered = 1
                      if (
                        compareIE( $it,
                                $test->getGroupName . '/'
                              . $test->getName
                              . '.yaml' ) == 0
                      );
                }
            }

            #skip already executed for --continue
            foreach my $et (@$executedtests) {
                $filtered = 1
                  if (
                    compareIE( $et,
                        $test->getGroupName . '/' . $test->getName . '.yaml' )
                    == 1
                  );
            }

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

            #WARN Dumper $test;
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
                if ( defined( $test->getParam('dangerous') )
                    && ( $test->getParam('dangerous') eq 'yes' ) )
                {
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
    DEBUG 'XTest::Core->loadEnvCfg';
    my $self = shift;
    my $fn   = shift;
    $fn = 'systemcfg.yaml' unless defined $fn;
    DEBUG "Load env configuration file [ $fn ]";
    my $envcfg = LoadFile($fn) or confess $!;

    #DEBUG Dumper $envcfg;
    my $env = undef;
    $env = XTest::TestEnvironment->new;
    $env->init($envcfg);

    #DEBUG Dumper $env;
    return $env;
}

sub loadTests {
    DEBUG 'XTest::Core->loadTests';
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
            my $test = XTest::Test->new;

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
    DEBUG 'XTest::Core->loadTestSuites';
    my $self = shift;
    my $file = $self->{'options'}->{'testdir'} . '/tags.yaml';
    INFO "Load tag file [ $file ]";
    my $cfg = LoadFile($file) or confess $!;

    #DEBUG Dumper $cfg;
    return $cfg->{'tags'};
}

__PACKAGE__->meta->make_immutable;

