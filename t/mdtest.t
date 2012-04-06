#
#===============================================================================
#
#         FILE:  mdtest.t
#
#  DESCRIPTION:  
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex
#      CREATED:  11/01/2011 03:28:03 AM
#===============================================================================

#!/usr/bin/perl -w
package mdtest;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;


use Xperior::Test;
use Xperior::Executor::MDTest;

my %options = ( 
    testdir => 't/testcfgs/mdtest/',
    workdir => '/tmp/test_wd',
    
);
my $cfg;
my $testcore;
my $tests;
my $exe;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub { 
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);      
    $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');
    $tests  =  $testcore->loadTests;
    $exe = Xperior::Executor::MDTest->new();
    $exe->init(@{$tests}[0], \%options, $cfg);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################




test plan => 2, d_prepareCommands    => sub {
    $exe->_prepareCommands;
    my $mfexp = 'lclient,mds'; 

    is($exe->machines,$mfexp,'Check machinefile');

    my $exp = '/usr/lib64/openmpi/bin/mpirun  -H lclient,mds -pernode  --prefix /usr/lib64/openmpi/  mdtest  -u -d /mnt/lustre// -n 10 -i 10';
    is($exe->cmd,$exp,'Check that cmd is correct');

    
};


test plan => 3, cReset    => sub {
    is($exe->getClients,0,'Check clients after init'); 


    $exe->cmd('test');
    $exe->reset;
    is($exe->cmd,'','check reset for cmd');

    $exe->addClient('test');
    is($exe->getClients,1, 'Check clients after adding');
};

test plan =>1 , n_Execute    => sub {
    #Log::Log4perl->easy_init($INFO);   
    $exe->execute;
    DEBUG Dumper $exe->yaml;
    is $exe->yaml->{'killed'},'no', 'Execution done check';
};


test plan =>5 , e_processLogs    => sub {
    Log::Log4perl->easy_init($DEBUG);   
    $exe->processLogs('t/testout/mdtest.test1.stderr.log');
     #DEBUG Dumper $exe->yaml;
    my $pe = $exe->yaml->{'measurements'};
    is(scalar(@$pe),8,'Parsed array elements');
    is( ${$pe}[0]->{'min_value'},'1441.441','array check');
    is( ${$pe}[2]->{'max_value'},'1735.694','array check');
    is( ${$pe}[6]->{'stddev_value'},'141.129','array check');
    is( ${$pe}[7]->{'name'},'Tree removal','array check');

};



mdtest->run_tests;

