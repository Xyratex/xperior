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

package ielists;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;

sub getTests{
    my $out = shift;
    my @res;
    foreach my $s (@$out){
        #print "# $s \n";
        if ( $s =~ m/Test\s+full\s+name\s+\:\s+\[(.+)\]/){
            #print "*********". $1."\n";
            push @res, $1;
        }
    }
    my @sortres = sort @res;
    return \@sortres;
}



startup         _startup  => sub {};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################

test plan => 1, cFullList => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml  --testdir=t/testlists/testds`;
    my $tts = getTests(\@out);
    my @exp = sort ((
          'replay-vbr/1a',
          'replay-vbr/1bx',
          'replay-vbr/1c',
          'replay-vbr/2a',
          'replay-vbr/2b',
          'replay-vbr/3a',
          'replay-vbr/3b',
          'replay-dual/6',
          'replay-dual/8',
          'replay-dual/9'
          ));
    is_deeply($tts,\@exp,"Full list");
    #print Dumper $tts;

};


test plan => 2, eIncludeList => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.simple.list`;
    my $tts = getTests(\@out);

    print "Ready results:".Dumper $tts;
    my @exp = sort (
           'replay-vbr/1a',
           'replay-dual/9'
          );

    is_deeply($tts,\@exp,"Simple include list ");


    my @out1 = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list`;
    my $tts1 = getTests(\@out1);

    my @exp1 = (
          'replay-dual/6',
          'replay-dual/8',
          'replay-dual/9'
          );
    is_deeply($tts1,\@exp1,"Simple include list with r/e");

};

test plan => 3, alIELists => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.simple.list               --excludelist=t/testlists/exclude.list`;
    my $tts = getTests(\@out);

    #print "Ready results:".Dumper $tts;
    my @exp = (
           'replay-dual/9',
           'replay-vbr/1a',
          );

    is_deeply($tts,\@exp,"Simple include list/exclude list 1");

    @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list               --excludelist=t/testlists/exclude.list`;
    $tts = getTests(\@out);

    #print "Ready results:".Dumper $tts;
    @exp = (
           'replay-dual/6',
           'replay-dual/8',
           'replay-dual/9'
          );

    is_deeply($tts,\@exp,"Simple include list/exclude list 2");

    my @out1 = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list     --excludelist=t/testlists/exclude_r.list`;
    my $tts1 = getTests(\@out1);

    #print "Ready results:".Dumper $tts1;
    my @exp1 = ('replay-dual/6',
                'replay-dual/8',
                'replay-dual/9');
    is_deeply($tts1,\@exp1,"Not empty result");
};

test plan => 1, aaIteratedIELists => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=t/testcfgs/localtestsystemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.simple.list   --multirun 3 --excludelist=t/testlists/exclude.list`;
    print "Output:".Dumper @out;
    my $tts = getTests(\@out);

    print "Ready results:".Dumper $tts;
    my @exp = (
           'replay-dual/9__0',
           'replay-dual/9__1',
           'replay-dual/9__2',
           'replay-vbr/1a__0',
           'replay-vbr/1a__1',
           'replay-vbr/1a__2',
          );

    is_deeply($tts,\@exp,"Simple include list/exclude list 1");
};

ielists->run_tests;
