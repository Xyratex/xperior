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
use XTest::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use XTest::Test;

my %options = ( 
    testdir => 't/testcfgs/simple/',
);
my $testcore; 
my $cfg ;


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub { 
    $testcore =  XTest::Core->new();
    $testcore->options(\%options);      
    $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################

test plan => 10, aGetNodeConfiguration    => sub {
    my $osss = $cfg->getOSSs;
    my $nid  = ((@$osss)[0])->{'node'};
    DEBUG "OSS ID=".$nid;
    my $node = $cfg->getNodeById($nid);
    DEBUG "Cfg dump".$node;
    $node->getNodeConfiguration;
    DEBUG $node->architecture;
    is($node->architecture,'x86_64','Check arch');
    
    DEBUG $node->os;
    is($node->os,'GNU/Linux','Check os');
    
    DEBUG $node->lustre_version;
    is($node->lustre_version,'jenkins-g26109ba-PRISTINE-2.6.32-131.6.1.el6.lustre.37.x86_64','Check lb');
    
    DEBUG $node->os_release;
    
    is($node->os_release,'6.0','Check os release');
    DEBUG $node->os_distribution;
    
    is($node->os_distribution,'Scientific Linux release 6.0 (Carbon)','Check os distr');
    
    DEBUG $node->lustre_net;                                                         
    is($node->lustre_net,'tcp','Check net');

    DEBUG $node->memtotal;                 
    is($node->memtotal,'743200','Check mem total');

    DEBUG $node->memfree;                 
    ok($node->memtotal > 100,'Check mem free');

    DEBUG $node->swaptotal;                 
    is($node->swaptotal,'1507320','Check swap total');

    DEBUG $node->swapfree;                 
    ok($node->swapfree > 100,'Check swap free');

};

test plan => 2, dCheckIP    => sub {
    is( $cfg->getNodeAddress('mds1'),'192.168.200.102');
    is( $cfg->getNodeAddress('client1'),'lclient');
};

test plan => 3, nCheckRemoteControls => sub{

    my $mc = $cfg->getNodeById($cfg->getMasterClient->{'id'});
    #test no real numbers because it can be different
    ok( $mc->getLFFreeSpace > 100,
            "Check free space:".$mc->getLFFreeSpace );
    ok( $mc->getLFFreeInodes > 100,
            "Check free nodes:".$mc->getLFFreeInodes );
    ok( $mc->getLFCapacity > 100,
            "Check capacity:".$mc->getLFCapacity );
};




test plan => 5, cCheckLustreObjects    => sub {
    #$cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');
    ok (defined $cfg, "Check parsing results");
   
    my $osss = $cfg->getOSSs;
    #print "OSSs:".Dumper $osss;
    my @exp1 = (
          {
            'type' => 'oss',
            'id' => 'oos1',
            'node' => 'oss1',
            'device' => '/dev/loop1'
          },
          {
            'type' => 'oss',
            'id' => 'oos2',
            'node' => 'oss2',
            'device' => '/dev/loop2'
          }
    );
    is_deeply($osss,\@exp1,"Check getOSSs");

    my $mdss = $cfg->getMDSs;
    my @exp2 = (
          {
            'type' => 'mds',
            'id' => 'mds1',
            'node' => 'mds1',
            'device' => '/dev/loop0'
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
    
    my $mc = $cfg->getMasterClient;
    is($mc->{'node'},'client1',"Check getMasterClient");

};

test plan => 4, kCheckRemoteControls => sub{

    my $mc = $cfg->getNodeById($cfg->getMasterClient->{'id'});
    my $rc     = $mc->getRemoteConnector;
    my $clone1 = $mc->getExclusiveRC;
    my $clone2 = $mc->getExclusiveRC;
    #test no real numbers because it can be different
    isnt( $rc, undef, "Check alive RC");
    isnt( $clone1, undef, "Check alive URC");
    isnt( $rc, $clone1, "Check clone and org diff");
    isnt( $clone2, $clone1, "Check clones diff");
};




#########################################
testenv->run_tests;




