#
#===============================================================================
#
#         FILE:  XTests::Core.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:   ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/05/2011 03:23:42 PM
#     REVISION:  ---
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

our $VERSION = "0.0.1";

has 'options'    => ( is => 'rw' );
has 'tests'      => ( is => 'rw',isa => 'ArrayRef[]', );
has 'testgroups' => ( is => 'rw'  );
has 'env'        => ( is => 'rw'  );


sub createExecutor{
    my ($self,$es) = @_;
    DEBUG "Loading module [$es]";
    load $es;
    return $es->new;
}

sub runtest{
    DEBUG "XTests::Core::runtest";
    my ($self, $test ) = @_;
    DEBUG "Starting tests ".$test->getParam('id');
    #DEBUG "Test is:". Dumper $test;
    my $executor = $self->createExecutor($test->getParam('executor'));
    $executor->init($test, $self->options, $self->env);
    $executor->execute;
    $executor->write();
    return $test->tap;
}

sub run {
    my $self    = shift;
    my $options = shift;
    $self->{'options'}=$options;
    DEBUG  "Start framework";
    my $tags  = $self->loadTags;
    $self->{'tests'} = $self->loadTests;
    $self->{'env'}   = $self->loadEnvCfg;
    $self->{'env'}->checkEnv;
    #TODO load exclude list

    #TODO check tests applicability there

    #start testing
    my @tests;
    my @rts = @{$self->{'tests'}};
    my %targs;
    foreach my $test ( @rts ){
        DEBUG "Test = ".Dumper $test;
        $self->runtest($test);
        WARN 'TEST '.$test->getName .' STATUS: '.$test->results->{'status'};
    }
}

sub loadEnvCfg{
    DEBUG 'XTests::Core->loadEnvCfg';
    my $self  = shift;
    my $fn    = shift;
    $fn = 'systemcfg.yaml' unless defined $fn;
    INFO "Load env configuration file [ $fn ]";
    my $envcfg = LoadFile( $fn ) or confess $!;
    #DEBUG Dumper $envcfg;  
    my $env = undef;
    $env = XTests::TestEnvironment->new;
    $env->init($envcfg);
    #DEBUG Dumper $env; 
    return $env;
}

sub loadTests{
    DEBUG 'XTests::Core->loadTests';
    my $self  = shift;
    my @testNames;
    my @tests;
    INFO "Find tests in dir:[". $self->{'options'}->{'testdir'}."]";
    find( sub { push (@testNames ,  $File::Find::name) if(  $File::Find::name =~ m/tests.yaml/)},
          $self->{'options'}->{'testdir'}
    );
    #DEBUG Dumper @testNames;
   
    foreach my $fn (@testNames){
        my $testscfg = $self->loadTestsFile($fn);
        my %groupcfg;
        foreach my $key ( keys %{$testscfg}){
            $groupcfg{$key} = $testscfg->{$key}
                if( $key ne 'Tests');
        }

        foreach my $testcfg (@{$testscfg->{'Tests'}}){
            my $test = XTests::Test->new;
            #DEBUG "groupcfg=".Dumper \%groupcfg;
            $test->init($testcfg,\%groupcfg);
            push @tests, $test;
       }
    }
   
    DEBUG 'Load tests result:'. Dumper \@tests ;
    return  \@tests ;
}

sub loadTestsFile{
    my $self  = shift;
    my $fn    = shift;
    INFO "Load test file [ $fn ]";
    my $testscfg = LoadFile( $fn ) or confess $!;
    #DEBUG Dumper $testscfg;  
    return $testscfg;
}

sub loadTags{
    DEBUG 'XTests::Core->loadTestSuites';        
    my  $self  = shift;
    my $file =  $self->{'options'}->{'testdir'}.'/tags.yaml';
    INFO "Load tag file [ $file ]";
    my $cfg = LoadFile( $file ) or confess $!;
    #DEBUG Dumper $cfg; 
    return $cfg->{'tags'};
}

__PACKAGE__->meta->make_immutable;


