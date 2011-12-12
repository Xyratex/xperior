#
#===============================================================================
#
#         FILE:  sshprocess.t
#
#  DESCRIPTION:  Tests for XTest::SshProcess class. Currently have hardcoded values for ryg's notebook 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex
#      VERSION:  1.0
#      CREATED:  10/08/2011 01:28:07 AM
#===============================================================================

#!/usr/bin/perl -w
package sshprocess;
use strict;
use Test::Able;
use Test::More;
use XTest::SshProcess;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use XTest::Test;
use XTest::SshProcess;
use XTest::Utils;

my $sp;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub { 
    $sp =  XTest::SshProcess->new();
    $sp->init('localhost','ryg');
};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################
test plan => 7, dCreateAliveKill    => sub {
    #highlevel functional test
    is($sp->killed,0, 'Check status before start');
    $sp->create('sleep','/bin/sleep 30');
    pass('App started');
    my $res = $sp->isAlive;
    is($res,0, 'Check alive for alive app');
    $sp->kill;
    $res = $sp->isAlive;    
    is($res,-1, 'Check alive for exited app');
    isnt($sp->killed,0, 'Check status after kill');
    isnt($sp->exitcode,undef, 'Check 1 exit code after kill');
    isnt($sp->exitcode,0, 'Check 2 exit code after kill');
};

test plan => 6, eCreateAliveExit    => sub {
    #highlevel functional test
    $sp->create('sleep','/bin/sleep 15');
    pass('App started');
    is( -e $sp->pidfile, 1,'Pid file exists');   
    my $res = $sp->isAlive;
    my $ec  = $sp->exitcode;
    is($res,0, 'Check alive for alive app');
    is($ec,undef, 'Check exit code for alive app');
    sleep 19;
    $res = $sp->isAlive;
    $ec  = $sp->exitcode;
    is($res, -1,  'Check alive for exited app');
    is($ec,  0, 'Check exit code for alive app');
};

test plan => 6, aSynExecution => sub {
  my $stime = time;
  $sp->createSync('/bin/sleep 10');
  my $etime = time;
  is($sp->exitcode,0,"Check exit code for correct syn execution");
  ok($etime-$stime< 15, "Check execution time");
  $sp->createSync('ls -la /folder/which/nobody/never/creates/');
  is($sp->exitcode,2,"Check exit code for failed syn execution");
  
  $stime = time;
  $sp->createSync('/bin/sleep 15',5);
  $etime=time;
  isnt($sp->exitcode,0,"Check exit code for failed operation");
  DEBUG "Execution was:".($etime-$stime);
  ok($etime-$stime < 12, "Check time of timeouted operation");

  $sp->createSync('/bin/sleep 10');
  is($sp->exitcode,0,"Check exit code for failed operation");
};


test plan => 20, xStress    => sub {
    for(my $i=0; $i<10; $i++){ 
        $sp->create('sleep','/bin/sleep 10');
        my $res = $sp->isAlive;
        is($res,0, "Check alive for alive app[$i]");
        sleep 10;
        $res = $sp->isAlive;
        is($res, -1,  "Check alive for exited app[$i]");
    }
};

test plan => 10, bInit    => sub {
    is($sp->host,'localhost','host');
    is($sp->user,'ryg','user');
    is($sp->hostname,trim `hostname`,'Check on host hostname');
    is($sp->osversion, trim`uname -a`,'Check os version');
    my $pidfile   = $sp->pidfile;
    my $ecodefile = $sp->ecodefile;
    my $rscrfile  = $sp->rscrfile;   
    $sp->init('localhost','ryg');
    isnt($pidfile,  $sp->pidfile,'Pid file is uniq');
    isnt($ecodefile,$sp->ecodefile, 'Exit code file is uniq');
    isnt($rscrfile, $sp->rscrfile, 'Script file is uniq');
    #is($exe->getClients,1, 'Check clients after adding')

    eval{ $sp->init('localhost','ryg');};
    is($@,'',"Connection ok");
    #negative initialization
    eval{ $sp->init('node_on_mars','ryg');};
    isnt($@,''," Connection failed as expected");
    eval{ $sp->init('localhost','ryg_on_mars');};
    isnt($@,''," Connection failed as expected");
};


#TODO add stress test and sendFile, getFile

sshprocess->run_tests;

