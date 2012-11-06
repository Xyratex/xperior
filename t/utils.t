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
