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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

#!/usr/bin/perl -w

package roleLoader;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Moose;
use Module::Load;
use File::Slurp;
use File::Path qw(make_path remove_tree);
use Xperior::Executor::Noop;
use Xperior::Executor::Roles::RoleLoader;

my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
      id          => 1,
      inf         => 'more info',
      rt_testvar  => '1',
      rt1_testvar => '2',
      commonvar   => '5',

);

my %gh = (
      executor     => 'Xperior::Executor::Noop',
      groupname    => 'sanity',
      rt_groupvar  => '3',
      rt1_groupvar => '4',
);

my $test;
my $exe;
my $cfg;
my $logfile = '/tmp/xp.test.log';
my $rl;

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub {
    $rl = Xperior::Executor::Roles::RoleLoader->new();
    unlink($logfile);
    Log::Log4perl->init(\ qq{
        log4perl.rootLogger                = DEBUG, Logfile, Screen
        log4perl.appender.Logfile          = Log::Log4perl::Appender::File
        log4perl.appender.Logfile.filename = /tmp/xp.test.log
        log4perl.appender.Logfile.layout = Log::Log4perl::Layout::SimpleLayout
        log4perl.appender.Logfile.autoflush =1
        log4perl.appender.Logfile.recreate  =1
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr  = 0
        log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
    });
    remove_tree('/tmp/test_wd');
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    $exe = Xperior::Executor::Noop->new();
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };

test plan =>3, cgetWeightCheck => sub{
    is($rl->getWeight('qwerty'),50,'check default value');
    is($rl->getWeight('ReformatBefore'),1,'check lower value');
    is($rl->getWeight('StoreConsole'),98,'check upper value');
};


test plan =>1, aaadFieldInitCheck => sub{
    my @roles = qw(RoleTest RoleTest1);
    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);

    $rl->weights({'RoleTest' => 1, 'RoleTest1'=>99});
    $rl->applyRoles($exe, $test, @roles);
    $exe->init($test, \%options, $cfg);

    #debug
    $exe->rt_printvars();
    $exe->rt1_printvars();

    is($exe->rt_get_testvar(),    1, "Check unique test var, TestRole");
    is($exe->rt1_get_testvar(),   2, "Check unique test var, TestRole1");
    is($exe->rt_get_groupvar(),   3, "Check unique group var, TestRole");
    is($exe->rt1_get_groupvar(),  4, "Check unique group var, TestRole1");
    is($exe->rt_get_commonvar(),  5, "Check unique common var, TestRole");
    is($exe->rt1_get_commonvar(), 5, "Check unique common var, TestRole1");

exit 1;
};


test plan =>4, fModuleLoadingOrder1 => sub{
    my @roles = qw(RoleTest RoleTest1);
    $rl->weights({'RoleTest' => 1, 'RoleTest1'=>99});
    $rl->applyRoles($exe, $test, @roles);
    $exe->init($test, \%options, $cfg);
    $exe->execute();
    #checks
    my @lines = read_file( $logfile );
    my @filtereddata;
    foreach my $line (@lines){
        if($line =~ /AFTER|BEFORE/){
            push @filtereddata,$line;
        }
    }
    DEBUG "\n".Dumper( @filtereddata);
    like($filtereddata[0], '/BEFORE\[beforeExecute\]\:RoleTest1/',
        'role1 before');
    like($filtereddata[2], '/BEFORE\[beforeExecute\]\:RoleTest\[/',
        'role before');
    like($filtereddata[4], '/BEFORE\[afterExecute\]\:RoleTest\[/',
        'role after');
    like($filtereddata[6], '/BEFORE\[afterExecute\]\:RoleTest1/',
        'role1 after');
};
test plan =>4, fModuleLoadingOrder2 => sub{
    my @roles = qw(RoleTest RoleTest1);
    $rl->weights({'RoleTest' => 99, 'RoleTest1'=>1});
    $rl->applyRoles($exe, $test, @roles);
    $exe->init($test, \%options, $cfg);
    $exe->execute();
    #checks
    my @lines = read_file( $logfile );
    my @filtereddata;
    foreach my $line (@lines){
        if($line =~ /AFTER|BEFORE/){
            push @filtereddata,$line;
        }
    }
    DEBUG "\n".Dumper( @filtereddata);
    like($filtereddata[0], '/BEFORE\[beforeExecute\]\:RoleTest\[/',
        'second check, role before');
    like($filtereddata[2], '/BEFORE\[beforeExecute\]\:RoleTest1\[/',
        'second check, role1 before');
    like($filtereddata[4], '/BEFORE\[afterExecute\]\:RoleTest1\[/',
        'second check, role1 after');
    like($filtereddata[6], '/BEFORE\[afterExecute\]\:RoleTest\[/',
        'second check, role after');
};

test plan =>1, kXperiorModuleLoading => sub{
    my $xpdir = 'lib/Xperior/Executor/Roles/*';
    my @files = glob( $xpdir );
    my @roles;
    foreach my $file (@files ){
        next if($file =~ /RoleLoader.pm/);
        if( $file =~ /^.*\/([\w\d]+)\.pm$/ ){
            push @roles, $1;
        }else{
            INFO "Cannot parse filename [$file]";
        }
    }
    $exe = Xperior::Executor::Noop->new();
    my $rl = Xperior::Executor::Roles::RoleLoader ->new();
    $rl->applyRoles($exe, $test, @roles);
    pass('Xperior internal roles applying is not failed');
};


#########################################
roleLoader->run_tests;
