#
#===============================================================================
#
#         FILE:  testenv.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  10/04/2011 08:35:07 PM
#     REVISION:  ---
#===============================================================================
#!/usr/bin/perl -w
package testenv;
use strict;
use Test::Able;
use Test::More;
use XTests::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use XTests::Test;

my %options = ( 
    testdir => 't/testcfgs/simple/',
);
my $testcore; 
my $cfg ;


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub { 
    $testcore =  XTests::Core->new();
    $testcore->options(\%options);      
    $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################
test plan => 2, dCheckIP    => sub {
    is( $cfg->getNodeAddress('mds1'),'192.168.200.102');
    is( $cfg->getNodeAddress('client1'),'lclient');
};
test plan => 4, cCheckLustreObjects    => sub {
    $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');
    ok (defined $cfg, "Check parsing results");
   
    my $osss = $cfg->getOSSs;
    #print "OSSs:".Dumper $osss;
    my @exp1 = (
          {
            'type' => 'oss',
            'id' => 'oos1',
            'node' => 'oss1',
            'device' => '/dev/sda1'
          }
    );
    is_deeply($osss,\@exp1,"Check getOSSs");

    my $mdss = $cfg->getMDSs;
    my @exp2 = (
          {
            'type' => 'mds',
            'id' => 'mds1',
            'node' => 'mds1',
            'device' => '/dev/sda1'
          }
        );
    #print "MDSs:".Dumper $mdss;
    is_deeply($mdss,\@exp2,"Check getMDSs");

    my $clients = $cfg->getClients;
    my @exp3 = (
          {
            'master' => 'yes',
            'type' => 'client',
            'id' => 'client1',
            'node' => 'client1',
          },
          {
            'type' => 'client',
            'id' => 'client2',
            'node' => 'client2',
          }
    );
    print "Clients:".Dumper $clients;
    is_deeply($clients,\@exp3,"Check getClients");


};
#########################################
testenv->run_tests;




