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

package core;
use strict;

use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;

my %options = (
    testdir => 't/testcfgs/simple/',
    workdir => '/tmp/test_wd/',
);
my $testcore;

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub {
    $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
};



##################################################
test plan => 1, fCheckRuntest          => sub {
    my @tests = @{$testcore->loadTests};
    #DEBUG "Executing tests";
    my $tap = $testcore->_runtest($tests[1]);
    #DEBUG "TAP:\n" . $tap;
    SKIP: {
        skip('Not finished, must be tested results from runtest',1);
        fail('TBI');
    };
};


################################################
test plan => 1, cCheckTagLoad           => sub {
    my $cfg = $testcore->loadTags;
    my @expected =  (
                    {
                      'name' => 'I/O Performance',
                      'id' => 'performance.io',
                      'description' => 'typical clustered filesystem performance benchmarks. Test subtypes: shared-single-file, file-per-process'
                    },
                    {
                      'name' => 'Metadata performance',
                      'id' => 'performance.md',
                      'description' => 'Test subtypes by operation and pattern (eg: directory-per-client create, shared directory create)'
                    }
);
    is_deeply($cfg,\@expected, 'Check tags');
};

#################################################
test  plan => 6, dCheckTests           => sub {
    my @tests = @{$testcore->loadTests};
    my $tn = @tests;
    is ( $tn, 2, 'Check test number' );
    is ( $tests[0]->getParam('id'), '1a', 'Check id');
    is ( $tests[0]->getParam('expected_time'), 10, 'Check ex time');
    is ( $tests[1]->getParam('id'), '2b' , 'Check id');
    is ( $tests[1]->getParam('groupname'), 'sanity' ,
                                        'Check groupname');
    diag( "2 groupname = ". $tests[1]->getParam('groupname') );

    my @tae = ('functional','sanity');
    is_deeply($tests[0]->getTags,\@tae, 'Check test tags');
#DEBUG Dumper $tests[0]->getTags;
};

##################################################
test plan => 1, dCheckCreateExecutor    => sub {

    my $exe = $testcore->_createExecutor('Xperior::Executor::Noop');
    diag("Class reference:$exe");
    isa_ok( $exe, 'Xperior::Executor::Noop', 'Check module loading' );
};

##################################################

teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };

core->run_tests;

