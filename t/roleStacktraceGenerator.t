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

#!/usr/bin/perl -w
package roleStacktraceGenerator;
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
use Xperior::Test;
use Xperior::Executor::Roles::StacktraceGenerator;
use Xperior::Executor::Roles::NetconsoleCollector;
use Xperior::Executor::Roles::StoreConsole;
my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
      id  => 1,
      inf => 'more info',
);

my %gh = (
      executor  => 'Xperior::Executor::Noop',
      groupname => 'sanity',
);

my $test;
my $exe;
my $cfg;

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub {
    remove_tree('/tmp/test_wd');
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

    $test = Xperior::Test->new;

    $test->init(\%th,\%gh);
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };

test plan =>2, eCheckSimpleLog => sub{
    #
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::StacktraceGenerator->meta->apply($exe);
    Xperior::Executor::Roles::NetconsoleCollector->meta->apply($exe);
    Xperior::Executor::Roles::StoreConsole->meta->apply($exe);
    $exe->init($test, \%options, $cfg);
    $exe->teststatus('fail');
    $exe->execute();
    is( scalar( keys( %{$exe->yaml->{'log'}} ) ),
        3, 'Check log  attachment array size' );
    is(
        $exe->yaml->{log}
          ->{'lctl_dk.lclient'},
        '1.lctl_dk.lclient.log', 'Check log record'
    );
};




#########################################
roleStacktraceGenerator->run_tests;
