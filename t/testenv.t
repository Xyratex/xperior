#
# GPL HEADER START
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 only,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License version 2 for more details (a copy is included
# in the LICENSE file that accompanied this code).
#
# You should have received a copy of the GNU General Public License
# version 2 along with this program; If not, see http://www.gnu.org/licenses
#
# Please  visit http://www.xyratex.com/contact if you need additional information or
# have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

package testenv;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use Xperior::Test;

my %options = (
    testdir => 't/testcfgs/simple/',
);
my $testcore;
my $cfg ;


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub {
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################

=head3 comment

comment it because needs special env

test plan => 10, aGetNodeConfiguration    => sub {
    my @osss = $cfg->getOSSs;
    my $nid  = ((@osss)[0])->{'node'};
    DEBUG "OSS ID=".$nid;
    my $node = $cfg->getNodeById($nid);
    DEBUG "Cfg dump".$node;
    $node->getConfig;
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

=cut

test plan => 4, dCheckIP    => sub {
    is( $cfg->getNodeAddress('mds1'),'mds');
    is( $cfg->getNodeAddress('client1'),'lclient');
    is( $cfg->getLustreNodeAddress('mds1'),'mdslustreip');
    is( $cfg->getLustreNodeAddress('client1'),'lclient');
};

=head3

comment it because needs special env

test plan => 3, nCheckRemoteControls => sub{

    my $mc = $cfg->getNodeById($cfg->geLustretMasterClient->{'id'});
    #test no real numbers because it can be different
    ok( $mc->getLFFreeSpace > 100,
            "Check free space:".$mc->getLFFreeSpace );
    ok( $mc->getLFFreeInodes > 100,
            "Check free nodes:".$mc->getLFFreeInodes );
    ok( $mc->getLFCapacity > 100,
            "Check capacity:".$mc->getLFCapacity );
};

=cut


test plan => 5, cCheckLustreObjects    => sub {
    ok (defined $cfg, "Check parsing results");

    my @osss = $cfg->getOSSs;
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
    is_deeply(\@osss,\@exp1,"Check getOSSs");

    my @mdss = $cfg->getMDSs();
    my @exp2 = (
          {
            'type' => 'mds',
            'id' => 'mds1',
            'node' => 'mds1',
            'device' => '/dev/loop0'
          }
        );
    #print "MDSs:".Dumper $mdss;
    is_deeply(\@mdss,\@exp2,"Check getMDSs");

    my $clients = $cfg->getLustreClients;
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
    is_deeply($clients,\@exp3,"Check getLustreClients");

    my $mc = $cfg->getMasterLustreClient;
    is($mc->{'node'},'client1',"Check getMasterClient");

};

=head3

comment it because needs special env

test plan => 4, kCheckRemoteControls => sub{

    my $mc = $cfg->getNodeById($cfg->getMasterLustreClient->{'id'});
    my $rc     = $mc->getRemoteConnector;
    my $clone1 = $mc->getExclusiveRC;
    my $clone2 = $mc->getExclusiveRC;
    #test no real numbers because it can be different
    isnt( $rc, undef, "Check alive RC");
    isnt( $clone1, undef, "Check alive URC");
    isnt( $rc, $clone1, "Check clone and org diff");
    isnt( $clone2, $clone1, "Check clones diff");
};

=cut


#########################################
testenv->run_tests;




