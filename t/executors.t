#
#===============================================================================
#
#         FILE:  executors.t
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex 
#      CREATED:  10/03/2011 06:36:20 PM
#===============================================================================
#!/usr/bin/perl -w
package executors;

use strict;
use Test::Able;
use Test::More;
use XTests::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

#use Noop for check Base functionality
use XTests::Executor::Noop;
use XTests::Test;

my %options = ( 
    workdir => '/tmp/test_wd',
);

my %th = (
      id  => 1,
      inf => 'more info',
     );

my %gh = (
      executor  => 'XTests::Executor::Noop',
      groupname => 'sanity',
        );
my $test;
my $exe; 

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 

    my $testcore =  XTests::Core->new();
    $testcore->options(\%options);      
    my $cfg = $testcore->loadEnvCfg('t/testcfgs/testsystemcfg.yaml');

    $test = XTests::Test->new;
    $test->init(\%th,\%gh);
    $exe = XTests::Executor::Noop->new();
    $exe->init($test, \%options, $cfg);
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################

test plan => 2, dCheckExternalLog    => sub {
    my $file =  "/tmp/test_log_file.xtest";
    open FILE, ">> $file" or confess "Cannot create file:". $!;
    ok(-e $file);
    $exe->registerLogFile('test1',$file);
    $exe->pass;
    my $res = $exe->tap;
SKIP:{
skip "Logic was changes",1;
my $exp = <<OUT
TAP version 13
1..1
ok 1
---
executor: XTests::Executor::Noop
groupname: sanity
id: 1
inf: 'more info'
log.test1: '/tmp/test_log_file.xtest'
result: 'ok 1'
OUT
;
    is($res,$exp)
     };
    close FILE;
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
    $exe->write;
    ok(-r $file);
    SKIP:{ pass ('TODO:check report data') };
};


test plan => 1, f_getMasterClient    => sub {
  my $node = $exe->_getMasterClient;
  is($node->{node},'client1','Check master node');
    
};



#########################################
executors->run_tests;




