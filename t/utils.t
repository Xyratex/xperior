#
#===============================================================================
#
#         FILE:  utils.t
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  11/27/2011 07:31:24 PM
#===============================================================================

#!/usr/bin/perl -w
package utils;
use strict;
use warnings;

use Test::Able;
use Test::More;
use Xperior::Utils;

use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub { };
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };

test plan => 5, dCompareIE => sub{
    my $res = compareIE("xxx","yyy");
    is($res,0,"Dummy check");
    $res = compareIE('sanity/1','sanity/1');
    is($res,1,"Simple check 0");
    $res = compareIE('sanity/*','sanity/1');
    is($res,0,"Simple regexp check"); 
    $res = compareIE('san*','sanity/1');   
    is($res,0,"Simple regexp check 2");               
    $res = compareIE('sanity','sanity/1');   
    is($res,0,"Simple regexp check 3");               

};


test plan => 1, gLoadEIFiles    => sub {
    my $res = parseFilterFile("t/data/iefile");
    DEBUG Dumper $res;
    my @exp = (
          'sanity/1',
          'sanity1',
          'sanity2/',
          'comment/1',
          'comment/2',
          'comment/3'
          );

    is_deeply($res,\@exp,'Check parsing results');
};

test plan => 1, aGetExecutedTestsFromWD => sub{
    my $res =  getExecutedTestsFromWD('t/data/wd');
    DEBUG Dumper $res;
    my @exp = (
          'mdtest/test1.yaml',
          'sanity/0b.yaml'
          );
    is_deeply($res,\@exp,'Check loaded test list');
};

utils->run_tests;
