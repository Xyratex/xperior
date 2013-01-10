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

use Xperior::Test;
use Xperior::Executor::LustreTests;
use Xperior::Executor::LustreSingleTests;

my %options = (
    testdir => 't/testcfgs/lustre/',
    workdir => '/tmp/test_wd',

);

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           _setup    => sub {

};
teardown        _teardown => sub { };
shutdown        _shutdown => sub {  };
#########################################

test plan => 3, aCheckLustreSingleTests => sub{
    my $tmpdir = '/tmp/mnt/lustre/';
    mkdir $tmpdir;
    my $wd = $CWD;
    my %gh = (
      executor  => 'Xperior::Executor::LustreSingleTests',
      groupname => 'single',
      timeout   => 600,
        );
    my %pth = (
      id  => 'pass',
      script => 'pass.sh',
     ); 
    
    my %fth = (
      id  => 'fail',
      script => 'fail.sh',
     ); 

    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    #########
    my $testp = Xperior::Test->new;
    $testp->init(\%pth,\%gh);
    my $exep = Xperior::Executor::LustreSingleTests->new();
    $exep->init($testp, \%options, $cfg);
    $exep->lustretestdir("$wd/t/lustre/bin/");
    $exep->execute();
    DEBUG 'Test:Result code :'.$exep->result_code;
    DEBUG 'Test:Reason      :'.$exep->getReason();
    is($exep->result_code,0,"Check exit code from pass.sh");
    ########
    my $testf = Xperior::Test->new;
    $testf->init(\%fth,\%gh);
    my $exef = Xperior::Executor::LustreSingleTests->new();
    $exef->init($testf, \%options, $cfg);
    $exef->lustretestdir("$wd/t/lustre/bin/");
    $exef->execute();
    DEBUG 'Test:Result code :'.$exef->result_code;
    DEBUG 'Test:Reason      :'.$exef->getReason();
    is($exef->result_code,1,"Check exit code from fail.sh");
    is($exef->yaml->{'fail_reason'} ,'Test return non-zero exit code :1'
        ,'Check reason');

    remove_tree($tmpdir);
};

lustresingleexec->run_tests;
