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
use MooseX::Storage;
use Carp qw( confess cluck );
use File::Path;
use File::chdir;
use Module::Load;

use TAP::Harness;
use TAP::Formatter::YamlFiles;
use XTests::Test;
use XTests::TestEnvironment;


has 'options'    => ( is => 'rw' );
has 'tests'      => ( is => 'rw',isa => 'ArrayRef[]', );
has 'testgroups' => ( is => 'rw'  );
has 'env'        => ( is => 'rw'  );


sub runtest{
    DEBUG "XTests::Core::runtest";
    my ( $harness, $teststr, $args ) = @_;
    #DEBUG "Ser data: $args";
    my $test = XTests::Test->thaw($args);
    DEBUG "Starting tests ".$test->getParam('id');
    #DEBUG "Test is:". Dumper $test;
    my $executor = createExecutor($test->getParam('executor'));
    #XTests::Executor::LustreTests->new();
    $executor->init($test);
    return $executor->execute;
     
=begin  

        <<TAP
TAP version 13
1..1
ok 1 
---
message: 'Failure message'
client log: | 
    == insanity test 0: Fail all nodes, independently == 12:30:06 (1313695806)
    Failing mds1 on node mds
    Stopping /mnt/mds1 (opts:)
    affected facets: mds1
    Failover mds1 to mds
    12:30:23 (1313695823) waiting for mds network 900 secs ...
    oss1: debug=0x33f0404
    oss1: subsystem_debug=0xffb7e3ff
    oss1: debug_mb=10
    Started lustre-OST0001
    Resetting fail_loc on all nodes...done.
    PASS 0 (70s)    
TAP
=cut

}
sub createExecutor{
#shift;
    my $es = shift;
    INFO "Loading module [$es]";
    load $es;
    return $es->new;
}

##################################################
# members
##################################################
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
    DEBUG "TAP Harness version is ". $TAP::Harness::VERSION;

    #ENV{'PERL_TEST_HARNESS_DUMP_TAP'}='/tmp/wd';
    my @tests;
    my @rts = @{$self->{'tests'}};
    my %targs;
    my $i=0;
    foreach my $test ( @rts ){
        DEBUG "Test = ".Dumper $test;
        $tests[$i][0]     = $test->id;
        $targs{$test->id} =   $test->freeze();
        $tests[$i][1]     = $test->id;
         $i++;
    }
    my %pargs= (
        verbosity   => 1, #FIXME - fix Session to put YAML not only in Verbose case
        timer       => 1,
        show_count  => 1,
        exec        => \&runtest ,
        formatter_class => 'TAP::Formatter::YamlFiles',
        #formatter_class => 'TAP::Formatter::HTML',
        #stdout     => $REPORT,
        workdir     => '/tmp/',
        test_args   => \%targs, 
    );
    
    #DEBUG "Tests before testing start:".Dumper \@tests;
    #DEBUG "\n\n\nTests args  before testing start:". Dumper( \%pargs)."**********\n\n\n";
    my $harness = TAP::Harness->new( \%pargs);
    my $aggregate = $harness->runtests( @tests );
    #print Dumper($aggregate);
    #DEBUG Dumper $harness;
}

sub loadEnvCfg{
    DEBUG 'XTests::Core->loadEnvCfg';
    my $self  = shift;
    my $fn = 'systemcfg.yaml';
    INFO "Load env configuration file [ $fn ]";
    my $envcfg = LoadFile( $fn ) or confess $!;
    DEBUG Dumper $envcfg;  
    my $env = XTests::TestEnvironment->new;
    $env->init($envcfg);
    DEBUG Dumper $env; 
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
   
    #DEBUG 'Load tests result:'. Dumper \@tests ;
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


