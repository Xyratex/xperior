#!/usr/bin/perl -w
package core;
use strict;

use Test::Able;
use Test::More;
use XTests::Core;
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
    $testcore =  XTests::Core->new();
    $testcore->options(\%options);
};



##################################################
test plan => 1, fCheckRuntest          => sub {
    my @tests = @{$testcore->loadTests};
    #DEBUG "Executing tests";
    my $tap = $testcore->runtest($tests[1]);
    #DEBUG "TAP:\n" . $tap;
    SKIP: {
        skip('Not finished, must be tested results from runtest',1);
        fail('TBI');
    };
};


################################################
test plan => 1, cCheckTags           => sub {
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
test  plan => 5, dCheckTests           => sub {
    my @tests = @{$testcore->loadTests};
    my $tn = @tests;
    is ( $tn, 2, 'Check test number' );
    is ( $tests[0]->getParam('id'), 1, 'Check id');
    is ( $tests[0]->getParam('expected_time'), 10, 'Check ex time');
    is ( $tests[1]->getParam('id'), 2 , 'Check id');
    is ( $tests[1]->getParam('groupname'), 'sanity' ,
                                        'Check groupname');
    diag( "2 groupname = ". $tests[1]->getParam('groupname') );
};

##################################################
test plan => 1, dCheckCreateExecutor    => sub {

    my $exe = $testcore->createExecutor('XTests::Executor::Noop');
    diag("Class reference:$exe");
    isa_ok( $exe, 'XTests::Executor::Noop', 'Check module loading' );
};

##################################################

teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };

core->run_tests;

