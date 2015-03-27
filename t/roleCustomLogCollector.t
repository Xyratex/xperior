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

package roleCustomLogCollector;
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
use Xperior::Executor::Noop;
use Xperior::Executor::Roles::CustomLogCollector;
use ReformatTestExecutor;

my $test;
my $exe;
my $cfg;

my $tmpfile ='/tmp/xperior_test_file_log_collected';
my $tmptfile ='/tmp/xperior_test_tmpl_file_log_collected';
my $nofile  = '/__not_exists_file__';

my $teststr='TESTFILE';
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
      collect_logs =>[$tmpfile,$nofile, '/tmp/xperior_test_tmpl_*']
);

#######################################


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
    write_file($tmpfile,$teststr);
    write_file($tmptfile,$teststr);

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
shutdown        _shutdown => sub {
    unlink $tmpfile;
};
#########################################

test plan => 4, cCheckPass => sub {
    $tests{collect_logs} = [$tmpfile,$nofile, '/tmp/xperior_test_tmpl_*'];
    $test->init(\%tests,\%group_config);
    $exe = ReformatTestExecutor->new();
    Xperior::Executor::Roles::CustomLogCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);


    $exe->lustretestdir($CWD.'/t/reformatbefore/pass/');
    $exe->execute();
    ok( -e '/tmp/test_wd/single/1.xperior_test_file_log_collected.client1.log',
        'check direct file collection #1');
    ok( -e '/tmp/test_wd/single/1.xperior_test_file_log_collected.mds1.log',
        'check direct file collection #2');
    ok( -e '/tmp/test_wd/single/1.xperior_test_tmpl_file_log_collected.client2.log',
        'check masked file collection #1');
    ok( -e '/tmp/test_wd/single/1.xperior_test_tmpl_file_log_collected.oss2.log',
        'check masked file collection #2');
};

my $testdir = '/tmp/xp_cstm_test_logs';
test plan => 4, fCheckSubDir => sub{
    $tests{collect_logs} = [ "$testdir/*"];
    $test->init(\%tests,\%group_config);

    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::CustomLogCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    remove_tree($testdir);
    mkdir $testdir;
    mkdir "$testdir/subdir";
    write_file( "$testdir/subdir/a.file", "test_subdir");
    write_file( "$testdir/a.file", "test_topdir");
    $exe->execute();
    ok( -e '/tmp/test_wd/single/1.a.file.client1.log',
        'check topdir a.file');
    is(read_file('/tmp/test_wd/single/1.a.file.client1.log'),
        'test_topdir',
            'check topdir a.file content');
    ok( -e '/tmp/test_wd/single/1.subdir_a.file.client1.log',
        'check subdir a.file');
    is(read_file('/tmp/test_wd/single/1.subdir_a.file.client1.log'),
        'test_subdir',
            'check subdir a.file content');


};


roleCustomLogCollector->run_tests;


