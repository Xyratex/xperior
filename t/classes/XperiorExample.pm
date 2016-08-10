package example_xperior_test;
use strict;
use warnings;
use Test::Class::Moose;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Log::Log4perl qw(:easy);
use File::Slurp;

my $wd     = '--workdir=/tmp/test_wd';
my $cfg    = '--config=t/testcfgs/testsystemcfg_generic.yaml';
my $tds    = '--testdir=testds';
my $cmd =  "bin/xper --action=run  $tds $cfg  $wd  --debug "
    ."--includeonly='examples/error_test    '";

sub test_setup {
    my $test = shift;
    $test->next::method;
    # more setup
    remove_tree('/tmp/test_wd');
}

sub test_error_execution {
    my $test   = shift;
    my $out;
    my $cmd =  "bin/xper --action=run  $tds $cfg  $wd  --debug "
            ."--includeonly='examples/error_test    '";
    print "CMD to run: $cmd \n";
    eval {
        $out = `$cmd`;
    };
    my $ec = ${^CHILD_ERROR_NATIVE};
    is( 0, $ec, 'error execution passed' );
    my $file = read_file( '/tmp/test_wd/examples/error_test.yaml');
    like( $file, qr/result: 'not ok 1  #Fail as ERROR :ERROR'/,
        'Check error message');

}

sub test_fail_execution {
    my $test   = shift;
    my $out;
    my $cmd =  "bin/xper --action=run  $tds $cfg  $wd  --debug "
        ."--includeonly='examples/fail_test'";
    print "CMD to run: $cmd \n";
    eval {
        $out = `$cmd`;
    };
    my $ec = ${^CHILD_ERROR_NATIVE};
    is( 0, $ec, 'fail execution passed' );
    my $file = read_file( '/tmp/test_wd/examples/fail_test.yaml');
    like( $file, qr/result: 'not ok 1  #Fail test by direct call :FAILED'/,
        'Check error message');

}

sub test_contains_execution {
    my $test   = shift;
    my $out;
    my $cmd =  "bin/xper --action=run  $tds $cfg  $wd  --debug "
        ."--includeonly='examples/contains_test'";
    print "CMD to run: $cmd \n";
    eval {
        $out = `$cmd`;
    };
    my $ec = ${^CHILD_ERROR_NATIVE};
    is( 0, $ec, 'contaisn execution passed' );
    my $file = read_file( '/tmp/test_wd/examples/contains_test.yaml');
    like( $file, qr/result: 'ok 1 '/,  'Check all passed');
    my  $log = read_file( '/tmp/test_wd/examples/contains_test.out.log' );
    like( $log, qr/Contains chech : PASSED/,
        'Check contains passed  message');
    like( $log, qr/not contains chech : PASSED/,
        'Check contains passed  message');
    like( $log, qr/custom chech sub : PASSED/,
        'Check contains passed  message');

}

sub test_run_check{
    my $test   = shift;
    my $out;
    my $cmd =  "bin/xper --action=run  $tds $cfg  $wd  --debug "
        ."--includeonly='examples/run_check_test'";
    print "CMD to run: $cmd \n";
    eval {
        $out = `$cmd`;
    };
    my $ec = ${^CHILD_ERROR_NATIVE};
    is( 0, $ec, 'run check execution passed' );

    my  $log = read_file( '/tmp/test_wd/examples/run_check_test.out.log' );
    like( $log, qr/Negative execution check : PASSED/,
                'Check negative execution check');
    like( $log, qr/Custom sub execution check : PASSED/,
        'Check custom sub execution check');
    like( $log, qr/param:12345/,
        'Check run_check with contains');
    like($log, qr/\+ echo]/,
        'Check run_check for empty output')
}


1;