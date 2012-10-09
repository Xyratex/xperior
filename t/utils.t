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

test plan => 1, aFindCompleteTests => sub{
    my $res =  findCompleteTests('t/data/wd');
    DEBUG Dumper $res;
    my @exp = (
          'mdtest/test1.yaml',
          'sanity/0b.yaml'
          );
    is_deeply($res,\@exp,'Check loaded test list');
};

utils->run_tests;
