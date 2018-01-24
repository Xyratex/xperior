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
# Author: Alexander Lezhoev<Alexander.Lezhoev@seagate.com>
#

package roleVmcoreGenerator;
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
use Xperior::Executor::Roles::VmcoreGenerator;

my $test;
my $exe;
my $cfg;
my %options = (
    testdir => 't/testcfgs/lustre',
    workdir => '/tmp/test_wd',
);
my %group_config = (
    executor  => 'Xperior::Executor::Noop',
    groupname => 'single',
    timeout   => 600,
    );

my %tests = (
      id  => 1,
      inf => 'more info',
      forced_teststatus => "fail",
);

#######################################


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub {
    remove_tree('/tmp/test_wd');
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%tests,\%group_config);
};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################

test plan => 3, cVmcoreGeneratorTests => sub {
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::VmcoreGenerator->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    my $testfile = "/tmp/vmcoregenerator-trigger";
    `sudo rm $testfile -f`;
    is(  !-e $testfile, 1,"file does not exists");
    is($exe->sysrqccmd, 'echo c > /proc/sysrq-trigger');
    $exe->sysrqccmd("echo -n c > $testfile");
    $exe->execute();
    my $data = read_file($testfile);
    is($data, 'c');
};

roleVmcoreGenerator->run_tests;

