#
#===============================================================================
#
#         FILE: node.t
#
#  DESCRIPTION: tests for Xperior::Node
#
#       AUTHOR: ryg
# ORGANIZATION: Xyratex
#      CREATED: 07/06/2012 09:38:52 PM
#===============================================================================
#!/usr/bin/perl -w
package nodetest;

use strict;
use warnings;
use Test::Able;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Error qw(try finally except otherwise);

startup some_startup => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup some_setup => sub {
    use Xperior::Node;
};
teardown some_teardown => sub { };
shutdown some_shutdown => sub { };
#########################################
test
  plan           => 7,
  aNodeBasicTest => sub {

    #default constructor
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost',
        id   => 'localhost'
    );
    try {
        $node->sync;
        fail('no exception thrown');
    }
    catch MethodNotImplementedException Error::subs::with {
        my $E = shift;
        pass "Catched";
    }
    catch Error::Simple Error::subs::with {
        fail "Should not be called";
    }
    finally {
        pass "Finally";
    };
    
    my $res =  $node->ping;
    is($res, 1, "positive ping check");

    my $ssh = $node->waitUp;
    isnt($ssh, undef, "positive waitUp check");

    my $sshcopy = $node->getRemoteConnector;
    is($ssh,$sshcopy,"check getRemoteConnector");

    my $sshclone = $node->getExclusiveRC;
    isnt($sshclone, undef, "positive getExclusiveRC check 1");
    isnt($sshclone,$ssh,"positive getExclusiveRC check 2");
  };


test plan => 2, nNegativePingCheck => sub {
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost123',
        id   => 'localhost'
    );
    my $res =  $node->ping;
    is($res, undef, "positive ping check");

    $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => '128.0.0.128', #believe that is bad ip
        id   => 'localhost'
    );
    $res =  $node->ping;
    is($res, 0, "positive ping check");

};

test plan => 2, nNegativeWaitUpCehck => sub{
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost123',
        id   => 'localhost'
    );
    my $ssh = $node->waitUp(10);
    is($ssh, undef, "negative waitUp check 1");
    is($node->rconnector, undef, "negative waitUp check 2");
};

#########################################
nodetest->run_tests;
