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
use File::Slurp;
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
     weight: 50
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
     weight: 50
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
test plan => 10, cCheckLogNormalization    => sub {
    my $testfile1 = '/tmp/test_wd/sanity/1.test1.log';
    my $testfile2 = '/tmp/test_wd/sanity/1.test2.zip';
    my $testfile3 = '/tmp/test_wd/sanity/1.test3.log';
    my $testfile4 = '/tmp/test_wd/sanity/1.test4.zip';
    my $testfile5 = '/tmp/test_wd/sanity/1.test5.log';

    my $logname1 = $exe->getNormalizedLogName('test1');
    is($logname1, $testfile1 , 'Check getNormalizedLogName #1');
    my $logname2 = $exe->getNormalizedLogName('test2','zip');
    is($logname2, $testfile2 , 'Check getNormalizedLogName #2');

    my $testsrcfile3 = '/tmp/test3.log';
    my $testsrcfile4 = '/tmp/test4.zip';
    my $testsrcfile5 = '/tmp/test5.log';
    my $data = 'Test report';

    write_file($testsrcfile3, $data);
    write_file($testsrcfile4, $data);
    my $res1 = $exe->normalizeLogPlace(
            $testsrcfile3,'test3');
    is ($res1,1,'Check exit code for normalizeLogPlace#1');
    ok(-r $testfile3);
    my $text = read_file($testfile3);
    is($text, $data, 'Check file content normalizeLogPlace#1');

    my $res2 = $exe->normalizeLogPlace(
            $testsrcfile4,'test4', 'zip');
    is ($res2,1,'Check exit code for normalizeLogPlace#2');
    ok(-r $testfile4);
    $text = read_file($testfile4);
    is($text, $data, 'Check file content normalizeLogPlace#2');

    my $res3 = $exe->normalizeLogPlace($testsrcfile5,'test5');    
    is ($res3, 0,'Check faield exit code for normalizeLogPlace#3');
    ok( not( -r $testfile5), 'No file check');

};
#########################################
test plan => 4, cCheckCreateLog    => sub {
    my $testfile1 = '/tmp/test_wd/sanity/1.test1.log';
    my $testfile2 = '/tmp/test_wd/sanity/1.test2.zip';
    my $data = 'Test report';
    my $fh = $exe->createLogFile('test1');
    print $fh $data;
    close $fh;
    ok(-r $testfile1);
    my $text = read_file($testfile1);
    is($text, $data, 'Check file content');

    $fh = $exe->createLogFile('test2','zip');
    print $fh $data;
    close $fh;
    ok(-r $testfile2);
    $text = read_file($testfile2);
    is($text, $data, 'Check file content');

};

#########################################

test plan => 4, cCheckReportWriting    => sub {

    my $dir  = $exe->_reportDir();
    is($dir,'/tmp/test_wd/sanity');
    my $file = $exe->_reportFile();
    is($file,'/tmp/test_wd/sanity/1.yaml');

    unlink $file;
    $exe->pass;
    $exe->report;
    ok(-r $file);
    SKIP:{ pass ('TODO:check report data') };
};


test plan => 1, f_getMasterNode    => sub {
  my $node = $exe->_getMasterNode();
  is($node->{node},'client1','Check master node');

};



#########################################
executors->run_tests;




