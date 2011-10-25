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
use XTests::SshProcess;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

use XTests::Test;
use XTests::SshProcess;
use XTests::Utils;

my $sp;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub { 
    $sp =  XTests::SshProcess->new();
    $sp->init('localhost','ryg');
};
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };
#########################################
test plan => 5, dCreateAliveKill    => sub {
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
};

test plan => 3, eCreateAliveExit    => sub {
    #highlevel functional test
    $sp->create('sleep','/bin/sleep 15');
    pass('App started');
    my $res = $sp->isAlive;
    is($res,0, 'Check alive for alive app');
    sleep 19;
    $res = $sp->isAlive;    
    is($res,-1, 'Check alive for exited app');
};

test plan => 4, cInit    => sub {
    is($sp->host,'localhost','host');
    is($sp->user,'ryg','user');
    is($sp->hostname,trim `hostname`,'Check on host hostname');
    is($sp->osversion, trim`uname -a`,'Check os version');
    #is($exe->getClients,1, 'Check clients after adding');
};

#TODO add stress test and sendFile, getFile

sshprocess->run_tests;

