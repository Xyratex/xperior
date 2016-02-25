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
# Copyright 2015 Seagate Technology
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#
package executorMultiNodeSingleprocesss;
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
use MultiNodeExecutorTest;

my $wd = '/tmp/test_wd';
my %options = (
    testdir => 't/testcfgs/generic',
    workdir => $wd,
);
my %group_config = (
    executor  => 'MultiNodeExecutorTest',
    groupname => 'multi',
    env       => {
                xxx => 'yyy'
                }
    );

my %test = (
    id  => 1,
    inf => 'more info',
    options => '-u 600  -p 10',
    timeout   => 15,
    polltime  => 2,
      env     => {
                qqq => 'zzz'
                }

);
my $test;
my $exe;
my $testcore;
my $cfg;

#######################################


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub {
    remove_tree($wd);
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg_generic.yaml');
    $test = Xperior::Test->new;
    $test->init(\%test,\%group_config);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################

=pod
test plan => 5, aaafBasicPayloadTest => sub {
    my %test = (
        id  => 1,
        inf => 'more info',
        options => '-u 600  -p 10',
        timeout   => 15,
        polltime  => 2,
        subtests  => {
                    generator => {
                        cmd      => 'echo qwerty',
                        timeout  => '50'
                    },
                    payload => {
                        cmd      => 'hostname',
                        timeout  => '50'
                    },
        }
    );
    $test = Xperior::Test->new;
    $test->init(\%test,\%group_config);

    $exe = MultiNodeExecutorTest->new();
    $exe->init($test, \%options, $cfg);
    $exe->execute();
    is($exe->result_code, 1, 'Check  status for basic timoeouted test');

    exit 1;
};
=cut

test plan => 4, cBasicMultiTest => sub {
    $exe = MultiNodeExecutorTest->new();
    $exe->init($test, \%options, $cfg);
    $exe->cmd("echo qazwsxedccrfv");
    $exe->execute();
    is($exe->result_code, 0, 'Check pass status for basic test');
    is($exe->yaml()->{subtests}->{subtest_client1}->{id}, 'client1',
        'Check multi test result structure #1');
    is($exe->yaml()->{subtests}->{subtest_client2}->{log}->{stderr},
        '1.client2.stderr.log',
            'Check multi test result structure #1');
    my $text = read_file( "$wd/multi/1.client1.stdout.log");
    is($text,"qazwsxedccrfv\n",'Check stdout');
    #DEBUG "**********". Dumper $exe->yaml;
};

test plan => 6, dBasicFailedMultiTest => sub {
    $exe = MultiNodeExecutorTest->new();
    $exe->init($test, \%options, $cfg);
    $exe->cmd('command_which_is_not_exists');
    $exe->execute();
    is($exe->result_code, 1, 'Check pass status for basic failed test');
    is($exe->yaml()->{subtests}->{subtest_client1}->{fail_reason},
        'Test return non-zero exit code :127',
        'Check failed multi test result structure #1');
    is($exe->yaml()->{subtests}->{subtest_client2}->{masterhostdown},
        'no',
            'Check failed multi test result structure #2');
    is($exe->yaml()->{subtests}->{subtest_client2}->{killed},
        'no',
            'Check failed multi test result structure #3');
    is($exe->yaml()->{subtests}->{subtest_client2}->{status},
        'failed',
            'Check failed multi test result structure #3');
    my $text = read_file( "$wd/multi/1.client1.stderr.log");
    like($text,qr/line 3: command_which_is_not_exists: command not found/,
    'Check stdout');
};

test plan => 5, fBasicTimeoutedTest => sub {
    $exe = MultiNodeExecutorTest->new();
    $exe->init($test, \%options, $cfg);
    $exe->cmd('sleep 60');
    $exe->execute();
    is($exe->result_code, 1, 'Check  status for basic timoeouted test');
    like(
        $exe->yaml()->{subtests}->{subtest_client1}->{fail_reason},
        qr/Killed by timeout after/,
        'Check timeouted multi test result structure #1');
    is($exe->yaml()->{subtests}->{subtest_client2}->{killed},
        'yes',
            'Check timeouted multi test result structure #2');
    is($exe->yaml()->{subtests}->{subtest_client2}->{completed},
        'yes',
            'Check timeouted multi test result structure #3');

    ok((($exe->yaml()->{subtests}->{subtest_client2}->{endtime} -
     $exe->yaml()->{subtests}->{subtest_client2}->{starttime})
        < 20), #15 - clear timeout, 20 with some reserve
        'Check kill timeout');
};

executorMultiNodeSingleprocesss->run_tests;
