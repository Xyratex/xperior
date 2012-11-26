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

package launcher;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;


startup         _startup  => sub {
 Log::Log4perl->easy_init({level => $DEBUG});
};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################
test plan => 3, nMultirun => sub {
    my $out=`bin/xper --testdir=t/testcfgs/simple  --action=list  --config=t/testcfgs/localtestsystemcfg.yaml --multirun 5 --debug`;
    my @ids;
    foreach my $str (split(/\n/,$out) ){
        DEBUG ">$str";
        if($str =~ m/Test\s+full\s+name\s+:\s+\[(.*)\]$/){
            push @ids, $1;
        }
    }
    is(scalar(@ids),10,'Number of tests');
    is($ids[1],'sanity/1a__1','Value check');
    is($ids[9],'sanity/2b__4','Value check 1');
};
#########################################
test plan => 3, mMultirun  => sub {
    my $out=`bin/xper --testdir=t/testcfgs/simple  --action=list  --config=t/testcfgs/localtestsystemcfg.yaml --multirun 5 --debug --includeonly='sanity/2b.*'`;
    my @ids;
    foreach my $str (split(/\n/,$out) ){
        DEBUG ">$str";
        if($str =~ m/Test\s+full\s+name\s+:\s+\[(.*)\]$/){
            push @ids, $1;
        }
    }
    is(scalar(@ids),5,'Number of tests');
    is($ids[1],'sanity/2b__1','Value check 2');
    is($ids[4],'sanity/2b__4','Value check 3');
};

#########################################
test plan => 5, oMultirun => sub {
    DEBUG `rm -rf /tmp/wd/` ;
    my $out=`bin/xper --workdir=/tmp/wd --testdir=t/testcfgs/simple  --action=run  --config=t/testcfgs/localtestsystemcfg.yaml --multirun 5 --debug --includeonly='sanity/2b.*'`;
    #DEBUG $out;
    my @ids;
    foreach my $str (split(/\n/,$out) ){
        #DEBUG ">$str";
        if($str =~ m/TEST\s+(.*)\s+STATUS\:\s+passed$/){
            push @ids, $1;
        }
    }
    is(scalar(@ids),5,'Number of tests');
    is($ids[1],'2b__1','Value check 2');
    is($ids[4],'2b__4','Value check 3');

    my $out1=`bin/xper --workdir=/tmp/wd --testdir=t/testcfgs/simple  --action=run  --config=t/testcfgs/localtestsystemcfg.yaml --multirun 6 --debug --includeonly='sanity/2b.*' --continue`;
    DEBUG $out1;
    my @ids1;
    foreach my $str (split(/\n/,$out1) ){
        #DEBUG ">$str";
        if($str =~ m/TEST\s+(.*)\s+STATUS\:\s+passed$/){
            push @ids1, $1;
        }
    }
    is(scalar(@ids1),1,'Number of tests');
    is($ids1[0],'2b__5','Value check 4');
};



#########################################
test plan => 2, jExitCodes => sub {

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/pass'`;
    my $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,0,"pass exit code");

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/exita.*'`;
    my $resa = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($resa,0xc00,"exitafter exit code");


};

launcher->run_tests;
