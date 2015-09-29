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

package executorLustreHA;
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
use Xperior::Executor::LustreHATests;

my $test;
my $exe;
my $testcore;
my %options = (
    testdir => 't/testcfgs/lustre',
    workdir => '/tmp/test_wd',
);
my %group_config = (
    executor  => 'Xperior::Executor::LustreHATests',
    groupname => 'single',
    timeout   => 600,
    env       => {
                xxx => 'yyy'
                }
    );

my %tests = (
      id  => 1,
      inf => 'more info',
      victims =>'oss0, oss1 ',
      options => '-u 600  -p 10',
    env     => {
                qqq => 'zzz'
                }

);

#######################################


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub {
    remove_tree('/tmp/test_wd');
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    #$cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg_cs9000.yaml');
    #'t/testcfgs/testsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%tests,\%group_config);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################

test plan => 3, cCheckHaOptions => sub {
    $exe = Xperior::Executor::LustreHATests->new();
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg_cs9000.yaml');
    $exe->init($test, \%options, $cfg);
    $exe->_prepareCommands();
    my $cmd = $exe->cmd();
    DEBUG "cmd=$cmd";
    like($cmd,
    qr/mkdir -p \/mnt\/testfs\/ && rm -rf \/mnt\/testfs\/\/\*/,
    'Simple ha.sh cmd check #1');
    like($cmd,
    qr/xxx="yyy" qqq="zzz" \/usr\/lib64\/lustre\/tests\/ha/,
    'Simple ha.sh cmd check #2');
    like($cmd,
    qr/-u 600  -p 10 -c oem-kvm1n1c0 -s kvm1n1c004,kvm1n1c005 -d \/mnt\/testfs\/  -v oss0, oss1/,
    'Simple ha.sh cmd check #3');
};




test plan => 2, cCheckProcessLogs => sub {
    $exe = Xperior::Executor::LustreHATests->new();
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    DEBUG Dumper $cfg->getMasterLustreClient();
    $exe->init($test, \%options, $cfg);
    #DEBUG Dumper $cfg;
    $exe->_prepareCommands();
    my $logdir = '/tmp/ha.sh_xp_test/';
    my $log1   = '/tmp/ha.sh_xp_test/test';
    my $log2   = '/tmp/ha.sh_xp_test_dk';
    mkdir $logdir;
    write_file( $log1, "log1");
    write_file( $log2, "log2");
    $exe->processLogs();
    ok( -e '/tmp/test_wd/single/1.ha.sh_xp_test_dk.client1.log',
        'check log1');
    ok( -e '/tmp/test_wd/single/1.test.client1.log',
        'check log2');
};


executorLustreHA->run_tests;

