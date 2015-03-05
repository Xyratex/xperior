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

package roleReformatBefore;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use File::Path qw(make_path remove_tree);
use File::chdir;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Slurp;

use Xperior::Test;
use Xperior::Executor::Roles::ReformatBefore;
use ReformatTestExecutor;

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
    $exe = ReformatTestExecutor->new();
    Xperior::Executor::Roles::ReformatBefore->meta->apply($exe);
    $exe->init($test, \%options, $cfg);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################

test plan => 6, cCheckPass => sub {
    $exe->lustretestdir($CWD.'/t/reformatbefore/pass/');
    $exe->execute();
    is($exe->yaml->{ReformatBefore_llmount_exitcode}, 0,
                    'pass:llmount exitcode');
    is($exe->yaml->{ReformatBefore_llmountcleanup_exitcode},0,
                    'pass:llmountcleanup exitcode');
    is($exe->{'result_code'}, 0, 'pass:test result check');
    if(defined($exe->yaml->{format_fail})){
        fail('pass:test exit property');
    }else{
        pass('pass:test exit property');
    }
    my @llmlines =
    read_file('/tmp/test_wd/single/1.ReformatBefore_llmount.stdout.log');
    is($llmlines[0],"Passed\n",'pass:llmount log');
    my @llclines =
    read_file(
        '/tmp/test_wd/single/1.ReformatBefore_llmountcleanup.stdout.log');
    is($llclines[0],"Passed\n",'pass:llmount log');
};

test plan => 4, dCheckLlmountcleanupFail => sub {
    $exe->lustretestdir($CWD.'/t/reformatbefore/fail/');
    $exe->execute();
    if(defined($exe->yaml->{ReformatBefore_llmount_exitcode})){
        fail('fail1:llmount exitcode');
    }else{
        pass('fail1:llmount exitcode');
    }
    is($exe->yaml->{ReformatBefore_llmountcleanup_exitcode},1,
                    'fail1:llmountcleanup exitcode');
    is($exe->{'result_code'}, 1, 'fail1:test result check');
    is($exe->yaml->{'format_fail'}, 'yes', 'fail1:test exit property');
};

test plan => 6, eCheckLlmountFail => sub {
    $exe->lustretestdir($CWD.'/t/reformatbefore/llmountfail/');
    $exe->execute();
    is($exe->yaml->{ReformatBefore_llmountcleanup_exitcode},0,
                    'fail2:llmountcleanup exitcode');
    is($exe->yaml->{ReformatBefore_llmount_exitcode},1,
                    'fail2:llmount exitcode');
    is($exe->{'result_code'}, 1, 'fail2:test result check');
    is($exe->yaml->{'format_fail'}, 'yes', 'fail2:test exit property');
    my @llmlines =
    read_file('/tmp/test_wd/single/1.ReformatBefore_llmount.stdout.log');
    is($llmlines[0],"Failed\n",'fail2:llmount log');
    my @llclines =
    read_file(
        '/tmp/test_wd/single/1.ReformatBefore_llmountcleanup.stdout.log');
    is($llclines[0],"Passed\n",'fail2:llmount log');
};


roleReformatBefore->run_tests;


