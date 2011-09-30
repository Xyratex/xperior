#!/usr/bin/perl -w
package CoreTest;

use Test::Able;
use Test::More;
use XTests::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;

my %options = ( 
    testdir => 't/testcfgs/simple/',
);
my $testcore; 
startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 
    $testcore =  XTests::Core->new();
    my %options = ( 
        testdir => 't/testcfgs/simple/',
    );
    $testcore->options(\%options);
};


##################################################
test plan => 1, yCheckRuntest          => sub {
    my @tests = @{$testcore->loadTests};
    #DEBUG "Executing tests";
    my $tap = XTests::Core::runtest('harness', 'testfile',$tests[1]->freeze);
    DEBUG "TAP:\n" . $tap;
my $exp = <<TAP
TAP version 13
1..1
not ok 1 
---
message: 'Noop engine, empty test '
testid: 2
TAP
;
is($tap,$exp);
};


################################################
test plan => 1, CheckTags           => sub {
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
    is_deeply($cfg,\@expected);
};

#################################################
test  plan => 5, xCheckTests           => sub {
    my @tests = @{$testcore->loadTests};
    my $tn = @tests;
    ok ( $tn == 2 );
    ok ( $tests[0]->getParam('id') == 1 );
    ok ( $tests[0]->getParam('expected_time') == 10 );


    ok ( $tests[1]->getParam('id') == 2 );
    ok ( $tests[1]->getParam('groupname') eq 'sanity' );
    diag( "2 groupname = ". $tests[1]->getParam('groupname') );
};

##################################################
test plan => 1, xCheckCreateExecutor    => sub {

    my $exe = XTests::Core::createExecutor('XTests::Executor::Noop');
    diag("Class reference:$exe");
    isa_ok( $exe, 'XTests::Executor::Noop' );
};

##################################################

teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };

CoreTest->run_tests;

