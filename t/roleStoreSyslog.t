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
package roleStoreSyslog;

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
use Xperior::Executor::Roles::StoreSyslog;
use Xperior::Executor::LustreTests;

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
my $remotefile = '/tmp/xp_messages_remote';
my $localfile  = 'xp_messages_attached';
my $storedir   = '/tmp/';
startup some_startup => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup some_setup => sub {

    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');

    $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    remove_tree('/tmp/test_wd');
    write_file( $remotefile, '' )
      or confess "Can't create $remotefile: $!";
};
teardown some_teardown => sub { };
shutdown some_shutdown => sub { };
#########################################

test
  plan         => 2,
  bSimpleCheck => sub {

    #
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::StoreSyslog->meta->apply($exe);
    $exe->init( $test, \%options, $cfg );
    $exe->storedir($storedir);
    $exe->remotelog($remotefile);
    $exe->logname($localfile);
    $exe->execute;
    print Dumper $exe->yaml->{log};

    #
    is( scalar( keys( $exe->yaml->{'log'} ) ),
        5, 'Check attachment array size' );
    is(
        $exe->yaml->{log}
          ->{'/tmp/test_wd/sanity/1.xp_messages_attached.client2.log'},
        '1.xp_messages_attached.client2.log', 'Check record'
    );
  };

#TODO add test for check log file monitorig correctness

#########################################
roleStoreSyslog->run_tests;
