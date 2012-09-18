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

#!/usr/bin/perl -w
package roleNetconsoleCollector;


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

use Xperior::Executor::Noop;
use Xperior::Test;
use Xperior::Executor::Roles::NetconsoleCollector;

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
my $test;
my $exe;
my $cfg;
startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 

    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);      
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

    $test = Xperior::Test->new;

    $test->init(\%th,\%gh);
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################

test plan =>2, eCheckSimpleLog => sub{
    #
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::NetconsoleCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    $exe->execute;
    #
    like($exe->yaml->{'messages'},qr/Netconsole collector bind on port/,
                    'Check message');
    is($exe->udpserverthr->is_running(),'','Check that no thread is running');
};


test plan =>8, gCheckDisributed => sub{
    #
    use ExecutorNetconsoleTest;
    $exe = ExecutorNetconsoleTest->new();
    Xperior::Executor::Roles::NetconsoleCollector->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    $exe->execute;
    DEBUG Dumper $exe->yaml;
    is($exe->yaml->{'log'}->{'netconsole.mds1'},'1.netconsole.mds1.log','mds log');
    is( scalar(keys %{$exe->yaml->{'log'}}),5,'count of registred logs');
    my $text = read_file
            ($options{workdir}.'/sanity/'.$exe->yaml->{'log'}->{'netconsole.mds1'});
    like($text,qr/===Test1===/,'check test1');
    like($text,qr/===Test3===/,'check test2');
    like($text,qr/Log collecting done/,'check end 1');
    my $text1 = read_file
        ($options{workdir}.'/sanity/'.$exe->yaml->{'log'}->{'netconsole.client1'}); 
    like($text1,qr/===Test2===/,'check test2');
    like($text1,qr/Log collecting done/,'check end 2');
    my $text3 = read_file
        ($options{workdir}.'/sanity/'.$exe->yaml->{'log'}->{'netconsole.client2'});
    like($text3,qr/Log collecting done/,'check end of empty log');
};

#########################################
roleNetconsoleCollector->run_tests;

