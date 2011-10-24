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
use XTests::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use XTests::Test;
use XTests::Executor::LustreTests;

my %options = ( 
    testdir => 't/testcfgs/simple/',
    workdir => '/tmp/test_wd',
    
);

my %th = (
      id  => '1a',
      inf => 'more info',
     );

my %gh = (
      executor  => 'XTests::Executor::LustreTests',
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
test plan => 2, cCheckSimple    => sub {
    my $testcore =  XTests::Core->new();
    $testcore->options(\%options);      
    my $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');
    
    my $test = XTests::Test->new;
    $test->init(\%th,\%gh);
    my $exe = XTests::Executor::LustreTests->new();
    $exe->init($test, \%options, $cfg);
    $exe->_prepareEnvOpts;
    print "MDS OPT:".$exe->mdsopt."\n";
    is($exe->mdsopt,
            ' MDSDEV1=/dev/sda1 mds1_HOST=192.168.200.102 ', 
            'Check MDS OPT');


    print "OSS OPT:".$exe->ossopt."\n";
    is($exe->ossopt,
            ' OSTDEV1=/dev/sda1 ost1_HOST=192.168.200.110 ', 
            'Check OSS OPT');                                

};

lustreexec->run_tests;
