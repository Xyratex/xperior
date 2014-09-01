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


test plan => 3, nNegativePingCheck => sub {
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost123',
        id   => 'localhost'
    );
    my $res =  $node->ping;
    is($res, undef, "negative ping check, hostname");

    $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => '128.0.0.128', #believe that is bad ip
        id   => 'localhost'
    );
    $res =  $node->ping;
    is($res, 0, "negative ping check, address");

    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost',
        id   => 'localhost',
        pingport => 22333,
    );
    my $res =  $node->ping();
    is($res, 0, "negative ping check, port");

};

test plan => 3, kPingPortCheck => sub {
    #TODO add to test autodetect other then ssh open port
    #on local host
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost',
        id   => 'localhost',
        pingport => 22,
    );
    my $res =  $node->ping();
    SKIP: {
        skip 'should use  non-ssh port',1;
        is($res, 1, "positive ping port check");
    };
    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost123',
        id   => 'localhost',
        pingport => 0,
    );
    my $res =  $node->ping();
    is($res, 1, "disabled ping check");

    my $node = Xperior::Node->new(
        user => 'tomcat',
        ip   => 'localhost123',
        id   => 'localhost',
        pingport => 'qwerty',
    );
    eval{ $res =  $node->ping();};
    like($@,qr/Incorrect port set for node localhost/,
            "Inccorect port ok");

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
