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
# Copyright 2016 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

package roleRemoteLogCollector;
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

use Xperior::Utils;
use Xperior::Test;
use Xperior::Executor::Noop;
use Xperior::Executor::Roles::RemoteLogCollector;

my $test;
my $exe;
my $cfg;

my $oss1_syslog = '/tmp/xperior_test_file_syslog_log';
my $oss1_conman = '/tmp/xperior_test_file_conman_log';
my $oss1_syslog_attached = '/tmp/test_wd/single/1.syslog.oss1.log';
my $oss1_conman_attached = '/tmp/test_wd/single/1.conman.oss1.log';

my $nofile  = '/__not_exists_file__';

my $teststr="TESTFILE\ntest line #1\ntest line #2\n";
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

my $testcore;
#######################################


startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
    #write_file($tmpfile,$teststr);
    write_file($oss1_syslog,$teststr);
    write_file($oss1_conman,$teststr)

};
setup           _setup    => sub {
    remove_tree('/tmp/test_wd');
    DEBUG `sudo rm -fv /tmp/xperior_conman.oss*`;
    DEBUG `sudo rm -fv /tmp/xperior_syslog.oss*`;
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%tests,\%group_config);

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {
    unlink $oss1_syslog;
    unlink $oss1_conman;
};
#########################################

test plan => 9, cCheckCollectionPassedTest => sub {
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::RemoteLogCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    $exe->keep_lines(1);

    $exe->execute();
    ok( (-e $oss1_syslog),
        'check if syslog log exists after test end');
    my @syslog = read_file($oss1_syslog_attached);
    is(scalar @syslog,2,'Check number of record in syslog/oss1');

    DEBUG "Check existence of  [$oss1_conman]";
    ok( (-e $oss1_conman_attached),
        'check if conman log exists after test end');
    my @conman = read_file($oss1_conman_attached);
    is(scalar @conman,2,'Check number of record in conman/oss1');

    ok( (not( -e '/tmp/test_wd/single/1.conman1.oss1.log')),
        'no log attached if no remote log found');
    like( $exe->yaml()->{messages},
         qr/Not all paramaters defined for 'collect' for\[conman1\/oss1\]/,
         'not all paramter defined');
    like( $exe->yaml()->{messages},
          qr/Collection of \'\/tmp\/xperior_test_file_conman2_log\' for record \[conman2\] failed with exit code 1/,
          'fail to collect');
    my $conman_ec = runEx('ls -la /tmp/xperior_conman.oss1*') >> 8;
    isnt($conman_ec,0,'No conman tail stdout should be found');
    my $syslog_ec = runEx('ls -la /tmp/xperior_syslog.oss1*') >> 8;
    isnt($syslog_ec,0,'No conman tail stdout should be found');

};

test plan => 4, kCheckCollectionFailTest => sub {
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::RemoteLogCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    $exe->keep_lines(1);
    $exe->yaml->{'forced_teststatus'} = 'fail';

    $exe->execute();
    ok( (-e $oss1_syslog_attached),
        'check if syslog log exists after test end');
    my @syslog = read_file($oss1_syslog_attached);
    DEBUG Dumper @syslog;
    is(scalar @syslog,2,'Check number of record in syslog/oss1');

    ok( (-e $oss1_conman_attached),
        'check if conman log exists after test end');
    my @conman = read_file($oss1_conman_attached);
    DEBUG Dumper @conman;
    is(scalar @conman,3,'Check number of record in conman/oss1');
};

test plan => 2, lCheckCollectionFailTestOnlyFail => sub {
    $exe = Xperior::Executor::Noop->new();
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg_only_failed.yaml');
    Xperior::Executor::Roles::RemoteLogCollector->meta->apply( $exe );
    $exe->init( $test, \%options, $cfg );
    $exe->keep_lines( 1 );
    $exe->yaml->{'forced_teststatus'} = 'fail';
    $exe->execute();

    ok( (-e $oss1_syslog_attached),
        'check if syslog log exists after test end');
    my @syslog = read_file($oss1_syslog_attached);
    is(scalar @syslog, 3, 'Check number of record in syslog/oss1');

};

test plan => 2, mCheckCollectionOnlyFail => sub {
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg_only_failed.yaml');
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::RemoteLogCollector->meta->apply( $exe );
    $exe->init( $test, \%options, $cfg );
    $exe->keep_lines( 1 );
    $exe->execute();
    DEBUG   `ls -la $oss1_syslog`;
    is ( (-e $oss1_syslog_attached), undef,
        'check if syslog log does not exists after test end');
    is( (-e $oss1_conman_attached),  undef,
        'check if conman log does not exists after test end');
};

roleRemoteLogCollector->run_tests;


