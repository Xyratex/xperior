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

package lustreexec;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use File::Path qw(make_path remove_tree);
use File::chdir;
use File::Slurp;
use Xperior::Test;
use Xperior::Executor::LustreTests;
use Xperior::Executor::LustreSingleTests;

my %options = (
    testdir => 't/testcfgs/lustre/',
    workdir => '/tmp/test_wd',

);

my %th = (
           id  => '1a',
           inf => 'more info',
);

my %gh = (
           executor  => 'Xperior::Executor::LustreTests',
           groupname => 'sanity',
);

startup _startup => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup _setup => sub {

};
teardown _teardown => sub { };
shutdown _shutdown => sub { };
#########################################

test
  plan         => 3,
  eCheckSimple => sub {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareEnvOpts;
    DEBUG "MDS OPT:" . $exe->mdsopt;
    is( $exe->mdsopt,
        'mds1_HOST=mds mds_HOST=mds MDSDEV1=/dev/loop0 MDSCOUNT=1',
        'Check MDS OPT' );

    DEBUG "OSS OPT:" . $exe->ossopt;
    is(
        $exe->ossopt,
'ost1_HOST=192.168.200.102 OSTDEV1=/dev/loop1 ost2_HOST=192.168.200.102 OSTDEV2=/dev/loop2 OSTCOUNT=2',
        'Check OSS OPT'
    );

    DEBUG "CLNT OPT:" . $exe->clntopt;
    is( $exe->clntopt,
        'CLIENTS=lclient RCLIENTS=\"mds\"',
        'Check Clients options' );
  };

test
  plan                   => 6,
  fCheckStdOutLogParsing => sub {
    my $exe = Xperior::Executor::LustreTests->new();
    Xperior::Executor::Roles::StoreSyslog->meta->apply($exe);
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $fr = $exe->processLogs('t/testout/9.stdout.log');
    is( $fr, $exe->FAILED, "Failed result" );
    like(
        $exe->yaml->{messages},
qr/Cannot list lctl logs files\[\/tmp\/test_logs\/1365001494\/replay-dual.test_9.*.1365001544.log\]/,
        'Check failure messages'
    );
    my $file1    = '/tmp/replay-dual.test_9.1.log';
    my $teststr1 = 'xperior test file 1';
    my $file2    = '/tmp/replay-dual.test_9.2.log';
    my $teststr2 = 'xperior test file 2';
    write_file( $file1, $teststr1 ) or confess "Can't create $file1: $!";
    write_file( $file2, $teststr2 ) or confess "Can't create $file2: $!";

    remove_tree('/tmp/test_wd');
    make_path('/tmp/test_wd/sanity/');
    $exe->init( $test, \%options, $cfg );
    $fr = $exe->processLogs('t/testout/9.stdout.log.realfile');

    my $resultstr1 =
      read_file('/tmp/test_wd/sanity/1a.lctllog.replay-dual.test_9.1.log');
    is( $teststr1,              $resultstr1, 'Compare files #1' );
    is( $exe->yaml->{messages}, '',          'Check that messages empty#1' );

    my $resultstr2 =
      read_file('/tmp/test_wd/sanity/1a.lctllog.replay-dual.test_9.2.log');
    is( $teststr2,              $resultstr2, 'Compare files #2' );
    is( $exe->yaml->{messages}, '',          'Check that messages empty#2' );

    unlink $file1;
    unlink $file2;
  };

test
  plan                   => 3,
  fCheckSystemLogParsing => sub {
    my $exe = Xperior::Executor::LustreTests->new();
    Xperior::Executor::Roles::StoreSyslog->meta->apply($exe);
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $mclient    = $exe->_getMasterClient;
    my $mclientobj = $exe->env->getNodeById( $mclient->{'node'} );
    my $connector  = $mclientobj->getRemoteConnector;

    $exe->processSystemLog( $connector, 't/testout/23b.messages.vm1.log' );
    like( $exe->yaml->{messages},
          qr/Cannot copy log file \[\/tmp\/lustre-log\.1360606441\.2365\]/,
          'Check messages' );

    my $file    = '/tmp/xp_test_file';
    my $teststr = 'xperior test file';
    write_file( $file, $teststr ) or confess "Can't create $file: $!";

    remove_tree('/tmp/test_wd');
    make_path('/tmp/test_wd/sanity/');
    $exe->init( $test, \%options, $cfg );
    $exe->processSystemLog( $connector,
                            't/testout/23b.messages.vm1.log.realfile' );
    DEBUG Dumper $exe->yaml;
    my $resultstr = read_file('/tmp/test_wd/sanity/1a.dump.0.log');
    is( $teststr,               $resultstr, 'Compare files' );
    is( $exe->yaml->{messages}, '',         'Check that messages empty' );
    unlink $file;
  };

test
  plan             => 3,
  dCheckLogParsing => sub {
    my $exe  = Xperior::Executor::LustreTests->new();
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $res = $exe->processLogs('t/testout/sanity.1a.stdout.log');
    is( $res, 0, 'Check PASS log' );
    $res = $exe->processLogs('t/testout/sanity.1a.f.stdout.log');
    is( $res, 100, 'Check no PASS log' );

    $res = $exe->processLogs('t/testout/recovery-small.24b.stdout.log');
    is( $res, 0, 'Check PASS log, special case "DEBUG MARKER"' );

  };

test
  plan            => 4,
  kCheckExecution => sub {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg   = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');
    my $tests = $testcore->loadTests;
    my $exe   = Xperior::Executor::LustreTests->new();
    $exe->init( @{$tests}[0], \%options, $cfg );
    $exe->_prepareCommands;
    DEBUG $exe->cmd;
    my $excmd =
'SLOW=YES NAME=ncli mds1_HOST=mds mds_HOST=mds MDSDEV1=/dev/loop0 MDSCOUNT=1 ost1_HOST=192.168.200.102 OSTDEV1=/dev/loop1 ost2_HOST=192.168.200.102 OSTDEV2=/dev/loop2 OSTCOUNT=2 CLIENTS=lclient RCLIENTS=\"mds\"  ONLY=1a DIR=/mnt/lustre//tmp/ PDSH=\"/usr/bin/pdsh -R ssh -S -w \" /usr/lib64/lustre/tests/sanity.sh';
    is( $exe->cmd, $excmd, "Check generated cmd" );
    $exe->execute;
    DEBUG Dumper $exe->yaml;
    is( $exe->yaml->{'status'}, 'passed', 'Check result' );
    is( $exe->yaml->{'executor'},
        'Xperior::Executor::LustreTests',
        'Check result' );
    is( -e '/tmp/test_wd/sanity/1a.mount-info.log',
        1, 'Check that mountinfo is saved' );
  };

lustreexec->run_tests;
