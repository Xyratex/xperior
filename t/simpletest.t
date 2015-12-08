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
# Copyright 2015 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#
package simpletest;
use strict;

use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use File::Path qw(make_path remove_tree);
use File::chdir;
use File::Copy::Recursive qw(fcopy );
use File::Slurp;

use Xperior::Test;
use Xperior::Executor::Noop;
use TAPI::SimpleTest;

use Error qw(try finally except otherwise);
use Xperior::Xception;


my ($test,$exe, $cfg);

my %options = (
    testdir => 't/testcfgs/lustre',
    workdir => '/tmp/test_wd',
);
my %group_config = (
    executor  => 'Xperior::Executor::Noop',
    groupname => 'xperior_tests',
    timeout   => 600,
    );

my %tests = (
      id  => 1,
      inf => 'more info',
);



startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);


};
my $stest;
setup           _setup    => sub {
    $stest = TAPI::SimpleTest->new();
    remove_tree('/tmp/test_wd');
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%tests,\%group_config);
    $exe = Xperior::Executor::Noop->new();
    $exe->init($test, \%options, $cfg);
    $stest->executor($exe);

};

teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################


test plan => 4, isCheck   => sub {
    my $res = $stest->is(value=>1,expected=>1, message=>'int ok check');
    is($res,1,'int ok check');
    $res = $stest->is(value=>'qaz',expected=>'qaz', message=>'string ok check');
    is($res,1,'string ok check');
    try{
        $res = $stest->is(value=>1,expected=>2, message=>'Check ok fail');
        fail ("No exception thrown for is");
    }catch TestFailed Error::subs::with{
        my $ex = shift;
        DEBUG 'catch';
        pass('Correct exception caught for is');
    }finally{
        DEBUG 'fin';
    };
    is($stest->failcount(),1,"Check fail count");
};


test plan => 4, containsCheck   => sub {
    my $res = $stest->contains(
                    value=>"aaaaaqwertyzzzzz",
                    expected=>"qwerty", message=>'contains check #1');
    is($res,1,'contact check #1');
    $res = $stest->contains(
                    value=>"aaaaaqwertyzzzzz",
                    expected=>"(a)+qwerty(z)+", message=>'contains check #2');
    is($res,1,'contact check #2');
    try{
        $res = $stest->contains(value=>"aa",expected=>"bb",
                    message=>'contains check #3');
        fail ("No exception thrown for contains");
    }catch TestFailed Error::subs::with{
        my $ex = shift;
        DEBUG 'catch';
        pass('Correct exception caught for contains');
    }finally{
        DEBUG 'fin';
    };
    is($stest->failcount(),1,"Check fail count");


};


test plan => 4, run_checkCheck   => sub {
    DEBUG "Prepare node";
    my $node = Xperior::SshProcess->new();
    $node->init('localhost','tomcat');
    DEBUG "Do test!";

    my $res = $stest->run_check(
                    node    => $node,
                    cmd     => "sleep 3",
                    timeout => 10,
                    message => 'run_check #1');

    is($res->{exitcode},0,'run_check ok');
    $res = $stest->run_check(
                    node     => $node,
                    cmd      => "echo qwerty",
                    contains => 'qwerty',
                    timeout  => 10,
                    message  => 'run_check #1');

    is($res->{exitcode},0,'run_check with contains');

    $res = $stest->run_check(
                    node     => $node,
                    cmd      => "ls /no_file_awaited",
                    timeout  => 5,
                    message  => 'run_check #1',
                    dontfail => 1,
                    );
    is($res->{exitcode},2,'run_check fail');
    try{
        $res = $stest->run_check(
                    node    => $node,
                    cmd     => "sleep 30",
                    timeout => 5,
                    message => 'run_check timeout');
        fail ("No exception thrown for run_check");
    }catch TestFailed Error::subs::with{
        my $ex = shift;
        DEBUG 'catch';
        pass('Correct exception caught for run_check');
    }finally{
        DEBUG 'fin';
    };


};

#########################################
simpletest->run_tests;

