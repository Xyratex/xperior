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

package executors;

use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

#use Noop for check Base functionality
use Xperior::Executor::Noop;
use Xperior::Test;

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

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub {

    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    $exe = Xperior::Executor::Noop->new();
    $exe->init($test, \%options, $cfg);
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################

test plan => 2, dCheckExternalLog    => sub {
    my $file =  "/tmp/test_log_file.xperior";
    open FILE, ">> $file" or confess "Cannot create file:". $!;
    ok(-e $file);
    $exe->registerLogFile('test1',$file);
    $exe->pass;
    my $res = $exe->tap();
    DEBUG $res;
    my $exp = <<OUT
TAP version 13
1..1
ok 1 
---
   datetime: ~
   extensions:
     executor: Xperior::Executor::Noop
     fail_reason: ''
     groupname: sanity
     id: 1
     inf: more info
     log:
       test1: /tmp/test_log_file.xperior
     messages: ''
     result: 'ok 1 '
     schema: Xperior1
     status: passed
     status_code: 0
     testname: 1
   message: ''
   source: sanity1
...
OUT
;
    is($res,$exp,'Check simple pass tap');
    close FILE;
};

#########################################
test plan => 2, aSimpleCheckTapResults => sub{
    $exe->fail('reason');
    my $fres = $exe->tap;
    my $fexp = <<OUT
TAP version 13
1..1
not ok 1  #reason
---
   datetime: ~
   extensions:
     executor: Xperior::Executor::Noop
     fail_reason: ' #reason'
     groupname: sanity
     id: 1
     inf: more info
     messages: ''
     result: 'not ok 1  #reason'
     status: failed
     status_code: 1
     testname: 1
   message: ''
   source: sanity1
...
OUT
;
    is($fres,$fres,'fail tap check');
    $exe->skip(1,"skip reason");
    my $sres = $exe->tap;
#    DEBUG $sres;
    my $sexp = <<OUT
TAP version 13
1..1
ok 1# SKIP  #skip reason
---
   datetime: ~
   extensions:
     executor: Xperior::Executor::Noop
     fail_reason: ' #skip reason'
     groupname: sanity
     id: 1
     inf: more info
     messages: ''
     result: 'ok 1# SKIP  #skip reason'
     status: skipped
     status_code: 2
     testname: 1
   message: ''
   source: sanity1
...
OUT
;
    is($sres,$sres,'skip tap check');
};

#########################################
test plan => 3, cCheckCreateLog    => sub {

    my $fh    = $exe->createLogFile('test1');
    print $fh 'Test report';
    close $fh;
    pass("Checked that no any file io crash observed");
    ok(-r '/tmp/test_wd/sanity/1.test1.log');
    SKIP:{ pass ('TODO:check log data') };

};

#########################################

test plan => 4, cCheckReportWriting    => sub {

    my $dir  = $exe->_reportDir;
    is($dir,'/tmp/test_wd/sanity');
    my $file = $exe->_reportFile;
    is($file,'/tmp/test_wd/sanity/1.yaml');

    unlink $file;
    $exe->pass;
    $exe->report;
    ok(-r $file);
    SKIP:{ pass ('TODO:check report data') };
};


test plan => 1, f_getMasterClient    => sub {
  my $node = $exe->_getMasterClient;
  is($node->{node},'client1','Check master node');

};



#########################################
executors->run_tests;




