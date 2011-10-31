#
#===============================================================================
#
#         FILE:  iorexec.t
#
#  DESCRIPTION:  
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex
#      VERSION:  1.0
#      CREATED:  10/08/2011 01:28:07 AM
#===============================================================================

#!/usr/bin/perl -w
package iorexec;
use strict;
use Test::Able;
use Test::More;
use XTests::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

#BEGIN {
#    push @INC, '/opt/xyratex/xtests/lib/'
#};

use XTests::Test;
use XTests::Executor::IOR;

my %options = ( 
    testdir => 't/testcfgs/ior/',
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
    $testcore =  XTests::Core->new();
    $testcore->options(\%options);      
    $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');
    $tests  =  $testcore->loadTests;
    $exe = XTests::Executor::IOR->new();
    $exe->init(@{$tests}[0], \%options, $cfg);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################
test plan => 2, d_prepareCommands    => sub {
    $exe->_prepareCommands;
    my $mfexp = 'lclient,mds'; 

    is($exe->machines,$mfexp,'Check machinefile');

    my $exp = '/usr/lib64/openmpi/bin/mpirun  -H lclient,mds -pernode  --prefix /usr/lib64/openmpi/  /usr/bin/IOR -a POSIX -i 5 -C -g -v -e -w -r -b 10m -t 4k -o /mnt/lustre//testfile';
    is($exe->cmd,$exp,'Check that cmd is correct');

    
};

#test plan => 2, e_prepareCommandsMP    => sub {
#    $exe->_prepareCommandsMpich2;  
#my $mfexp = 
#"192.168.200.150:1\n".
#'192.168.200.102:1';
#
#    is($exe->machinefile,$mfexp,'Check machinefile');
#
#    my $exp = 'mpiexec   -machinefile /tmp/ior_machinefile -n 2  /usr/bin/IOR -a POSIX -i 5 -C -g -v -e -w -r -b 10m -t 4k -o /mnt/lustre//testfile';
#    is($exe->cmd,$exp,'Check that cmd is correct');
#
#    
#};

test plan => 3, cReset    => sub {
    is($exe->getClients,0,'Check clients after init'); 


    $exe->cmd('test');
    $exe->reset;
    is($exe->cmd,'','check reset for cmd');

    $exe->addClient('test');
    is($exe->getClients,1, 'Check clients after adding');
};

test plan =>1 , e_Execute    => sub {
    #Log::Log4perl->easy_init($INFO);   
    $exe->execute;
    DEBUG Dumper $exe->yaml;
    is $exe->yaml->{'killed'},'no', 'Execution done check';
};



iorexec->run_tests;

