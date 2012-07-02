#
#===============================================================================
#
#         FILE:  lustreexec.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  10/05/2011 11:35:54 PM
#     REVISION:  ---
#===============================================================================
#!/usr/bin/perl -w
package lustreexec;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use Xperior::Test;
use Xperior::Executor::LustreTests;

my %options = ( 
    testdir => 't/testcfgs/lustre/',
    workdir => '/tmp/test_wd',
    
);

my %th = (
      id  => '1a',
      inf => 'more info',
     );

my %gh = (
      executor  => 'Xperior::Executor::LustreTests',
      groupname => 'sanity',
        );

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub { 

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################
test plan => 3, eCheckSimple    => sub {
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);      
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');
    
    my $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init($test, \%options, $cfg);
    $exe->_prepareEnvOpts;
    DEBUG "MDS OPT:".$exe->mdsopt;
    is($exe->mdsopt,
            'MDSCOUNT=1 MDSDEV1=/dev/loop0 mds1_HOST=192.168.200.102  mds_HOST=192.168.200.102 ', 
            'Check MDS OPT');


    DEBUG "OSS OPT:".$exe->ossopt;
    is($exe->ossopt,
            'OSTCOUNT=2  OSTDEV1=/dev/loop1  ost1_HOST=192.168.200.102   OSTDEV2=/dev/loop2  ost2_HOST=192.168.200.102 ', 
            'Check OSS OPT');                                

    DEBUG "CLNT OPT:".$exe->clntopt;
    is($exe->clntopt,
            'CLIENTS=lclient RCLIENTS=\"mds\"',
            'Check Clients options');
};

test plan =>2, gCheckLogParsing => sub{
    my $exe = Xperior::Executor::LustreTests->new();
    my $res = $exe->processLogs('t/testout/sanity.1a.stdout.log');
    is($res,0,'Check PASS log');
    $res = $exe->processLogs('t/testout/sanity.1a.f.stdout.log');
    is($res,100,'Check no PASS log');

};

test plan =>3, kCheckExecution => sub{
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);      
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');
    my $tests  =  $testcore->loadTests;
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init(@{$tests}[0], \%options, $cfg);
    $exe->_prepareCommands;
    DEBUG $exe->cmd;
    my $excmd =  'SLOW=YES  MDSCOUNT=1 MDSDEV1=/dev/loop0 mds1_HOST=192.168.200.102  mds_HOST=192.168.200.102  OSTCOUNT=2  OSTDEV1=/dev/loop1  ost1_HOST=192.168.200.102   OSTDEV2=/dev/loop2  ost2_HOST=192.168.200.102  CLIENTS=lclient RCLIENTS=\"mds\"  ONLY=1a DIR=/mnt/lustre//tmp/  PDSH=\"/usr/bin/pdsh -R ssh -S -w \" /usr/lib64/lustre/tests/sanity.sh';
    is($exe->cmd,$excmd,"Check generated cmd");
    $exe->execute;
    DEBUG Dumper $exe->yaml;
    is($exe->yaml->{'status'},'passed', 'Check result');
    is($exe->yaml->{ 'executor'}, 'Xperior::Executor::LustreTests', 'Check result');
};

lustreexec->run_tests;
