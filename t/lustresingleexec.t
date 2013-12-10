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

package lustresingleexec;
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

use Xperior::Test;
use Xperior::Executor::LustreTests;
use Xperior::Executor::LustreSingleTests;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub { };
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################
my %options = (
    testdir => 't/testcfgs/lustre',
    workdir => '/tmp/test_wd',
);
my %group_config = (
    executor  => 'Xperior::Executor::LustreSingleTests',
    groupname => 'single',
    timeout   => 600,
    );

my @test_cases = (
    {
        test_config => {
            id  => 'pass',
            script => 'pass.sh',
        },
        expected => {
            result_code => 0,
            fail_reason => undef,
        },
    },
    {
        test_config => {
            id  => 'fail',
            script => 'fail.sh',
        },
        expected => {
            result_code => 1,
            fail_reason => "Test return non-zero exit code :1",
        },
    },
);

test plan => 2 * @test_cases, cCheckLustreSingleTests => sub {
    my $tmpdir = '/tmp/mnt/lustre';
    mkdir $tmpdir;
    my $wd = $CWD;

    my $testcore =  Xperior::Core->new();
    $testcore->options({%options});
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    for my $case (@test_cases) {
        my $test = Xperior::Test->new;
        $test->init($case->{test_config}, \%group_config);
        my $exec = Xperior::Executor::LustreSingleTests->new();
        $exec->init($test, {%options}, $cfg);
        $exec->lustretestdir("$wd/t/lustre/bin");
        $exec->execute();
        DEBUG 'Test:Result code :'.$exec->result_code;
        DEBUG 'Test:Reason      :'.$exec->getReason();
        is($exec->result_code,
            $case->{expected}->{result_code},
                "Check exit code from $case->{test_config}->{script}");
        is($exec->yaml->{'fail_reason'}, 
            $case->{expected}->{fail_reason},
                "Check fail reason");
    }

    remove_tree($tmpdir);
};

test
  plan             => 2,
  aaadCheckLogParsing => sub {
    my $exe  = Xperior::Executor::LustreSingleTests->new();
    my $test = Xperior::Test->new;
    my %test_config = (
            id  => 'runtests',
            script => 'runtests',
            );
    fcopy('t/testout/runtests.stdout.log',
        '/tmp/runtests..123.1386235452.log');
    $test->init(\%test_config, \%group_config);
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );
    my $res = $exe->processLogs('t/testout/runtests.stdout.log');
    is( $res, 0, 'Check PASS log' );
    ok(-e '/tmp/test_wd/single/runtests.lctllog.runtests..123.1386235452.log',
        'Check copied file existence');
};


lustresingleexec->run_tests;
