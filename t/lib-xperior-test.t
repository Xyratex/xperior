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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<roman.grigoryev@seagate.com>
#

#!/usr/bin/perl -w
package lib_xperior_test;
use strict;
use Test::Able;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Moose;
use Module::Load;
use File::Slurp;
use File::Path qw(make_path remove_tree);

use Xperior::Test;
my $test;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub {
    $test = Xperior::Test->new;

};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};

#########################################

test plan => 2, eGetTestName    => sub {
    my $testcfg = {
        id  => '999',
    };
    my $groupcfg = {
        groupname => 'testgrp',
    };
    $test = Xperior::Test->new;
    $test->init($testcfg, $groupcfg);
    my $name = $test->getTestName();
    is($name,'999','No name defined, set by init');
    $test->testcfg->{testname} = undef;
    my $name1 = $test->getTestName();
    is($name1,'','No name defined, hacked');

};

test plan => 4, kEnvMerge    => sub {
    my $testcfg = {
        id  => '999',
        env=>{
            xxx => 'common_data',
            yyy => 'test_data',
            zzz => 'test_only_data',
        },
    };
    my $groupcfg = {
        groupname => 'testgrp',
        env =>{
            aaa => 'group_only_data',
            xxx => 'common_data',
            yyy => 'group_data',
        },
    };
    $test->init($testcfg, $groupcfg);
    my $env = $test->getMergedHashParam("env");
    print Dumper $test;
    is($env->{'xxx'},'common_data','Common data');
    is($env->{'yyy'},'test_data','Test overrides data');
    is($env->{'aaa'},'group_only_data','Defined only in grp');
    is($env->{'zzz'},'test_only_data','Defined only in test');

};

lib_xperior_test->run_tests;

