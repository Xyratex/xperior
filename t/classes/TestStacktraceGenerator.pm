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
# Copyright 2013 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#
# Co-Author: Ashish Maurya <ashish.maurya@seagate.com>
#

package test_stack_trace_generator;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Test::Class::Moose;
use File::Slurp;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);

use Xperior::Core;
use Xperior::Executor::Noop;
use Xperior::Test;
use Xperior::Executor::Roles::StacktraceGenerator;

my $console_file = '/tmp/xp_local_console_file';

my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
      id  => 1,
      inf => 'more info',
);

my %gh = (
      executor  => 'Xperior::Executor::XTest',
      groupname => 'sanity',
);

my $exe;
my $cfg;
my $wd = '/tmp/test_wd';
my $test_suite = 'sanity';

sub test_setup {
    my $test = shift;
    $test->next::method;
    Log::Log4perl->easy_init($DEBUG);
    remove_tree($wd);
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    make_path("$wd/$test_suite");
}

sub test_check_log_files_proc {
    DEBUG "Test 'check_log_files_proc' started";
    write_file( $console_file, '' )
        or confess "Can't create $console_file: $!";

    my $test = shift;
    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::StacktraceGenerator->meta->apply($exe);
    $exe->proctcmd('/bin/ls -l /proc/');
    $exe->lctldkcmd('/bin/ls -l /tmp/');
    $exe->init($test, \%options, $cfg);
    $exe->teststatus('fail');
    $exe->execute();
    my $memorytrace_file = "$wd/$test_suite/1.memorytrace.client1.log";
    my $stacktrace_file = "$wd/$test_suite/1.stacktrace.client1.log";
    my $lctldk_file = "$wd/$test_suite/1.lctl_dk.client1.log";
    my $mtsize = -s $memorytrace_file;
    my $stsize = -s $stacktrace_file;
    my $ldsize = -s $lctldk_file;

   if ( is(-e '/tmp/test_wd/sanity/1.memorytrace.client1.log',
        1, 'Check attached memorytrace log files') ) {
   isnt($mtsize, 0, 'Check memorytrace file size');
    }

    if ( -e '/tmp/test_wd/sanity/1.stacktrace.client1.log') {
        is(-e '/tmp/test_wd/sanity/1.stacktrace.client1.log',
         1, 'Check attached stacktrace log files');
        isnt($stsize, 0, 'Check stacktrace file size');
    } else {
    # If stacktrace doesn't exist check for sysrqtrace
        is(-e '/tmp/test_wd/sanity/1.sysrqtrace.client1.log',
        1, 'Check attached sysrqtrace log files');
    }

    if ( is($exe->yaml->{log}->{'lctl_dk.client1'},
        '1.lctl_dk.client1.log', 'Check lctldk log record') ) {
    isnt($ldsize, 0, 'Check lctldk log file size');
    }

    #cleanup for Noop
    my @allnodes =  @{$exe->env->cfg->{'LustreObjects'}};
    my @nodes = map { $_->{'node'} } @allnodes;
    foreach my $n (@nodes) {
        my $mclientobj = $exe->env->getNodeById($n);
        my $node  = $mclientobj->getRemoteConnector();
        $node->masterprocess->kill();
    }
}

sub test_check_log_files_sysrq {
    DEBUG "Test 'check_log_files_sysrq' started";
    write_file( $console_file, '' )
        or confess "Can't create $console_file: $!";
    my $sysrqtrace_file = "$wd/$test_suite/1.sysrqtrace.client1.log";
    my $srqtsize = -s $sysrqtrace_file;

    my $test = shift;
    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::StacktraceGenerator->meta->apply($exe);
    $exe->sysrqtcmd('touch /tmp/dmesg; echo "SysRq
This is fake sysrq check
Sched Debug Version:" > /tmp/dmesg');
    $exe->dmesgcmd('cat /tmp/dmesg');
    $exe->lctldkcmd('rm -f /tmp/dmesg; /bin/ls -l /tmp/');
    $exe->proccmd_timeout('2');
    $exe->init($test, \%options, $cfg);
    $exe->teststatus('fail');
    $exe->execute();

    if ( is(-e '/tmp/test_wd/sanity/1.sysrqtrace.client1.log',
        1, 'Check attached sysrqtrace log files') ) {
    isnt($srqtsize, 0, 'Check sysrqtrace file size');
    }

    #cleanup for Noop
    my @allnodes =  @{$exe->env->cfg->{'LustreObjects'}};
    my @nodes = map { $_->{'node'} } @allnodes;
    foreach my $n (@nodes) {
        my $mclientobj = $exe->env->getNodeById($n);
        my $node  = $mclientobj->getRemoteConnector();
        $node->masterprocess->kill();
    }

}

1;
