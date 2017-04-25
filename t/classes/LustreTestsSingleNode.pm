package test_lustre_test_single_node;

use strict;
use warnings;
use Test::Class::Moose;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Log::Log4perl qw(:easy);
use File::Slurp;

use Xperior::Core;
use Xperior::Test;
use Xperior::Executor::LustreTests;
use Xperior::Executor::LustreSingleTests;
use Xperior::Executor::Roles::StoreSyslog;

my %options = (
    testdir => 't/testcfgs/lustre/',
    workdir => '/tmp/test_wd',

);

my %th = (
    id  => '1a',
    inf => 'more info',
);

my %gh = (
    executor  => 'Xperior::Executor::LustreTests',
    groupname => 'sanity',
);

sub test_setup {
    my $test = shift;
    $test->next::method;
    # more setup
    Log::Log4perl->easy_init($DEBUG);
}

sub test_check_cmd_generation {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');

    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareEnvOpts;
    DEBUG "MDS OPT:" . $exe->mdsopt;
    is( $exe->mdsopt,
        'NETTYPE=tcp mds1_HOST=mdslustreip MDSDEV1=/dev/loop0 mds_HOST=mdslustreip MDSDEV=/dev/loop0 MDSCOUNT=1',
        'Check MDS OPT' );

    DEBUG "OSS OPT:" . $exe->ossopt;
    is(
        $exe->ossopt,
        'ost1_HOST=192.168.200.102 OSTDEV1=/dev/loop1 ost2_HOST=192.168.200.102 OSTDEV2=/dev/loop2 OSTCOUNT=2',
        'Check OSS OPT'
    );

    DEBUG "CLNT OPT:" . $exe->clntopt;
    is( $exe->clntopt,
        'CLIENTS=lclient RCLIENTS="mds"',
        'Check Clients options' );
}

sub test_check_cmd_mgs_generation {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemmgscfg.yaml');

    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareEnvOpts;
    DEBUG "MGS OPT: " . $exe->mgsopt;
    #    is ( $exe->mgsopt,
    #        'mgs_HOST=192.168.200.1 MGSDEV=/dev/vdb mgsfailover_HOST=192.168.200.2 MGSNID=192.168.200.1@tcp:192.168.200.2@tcp',
    #        'Check MGS options');
    is ( $exe->mgsopt,
        'mgs_HOST=192.168.200.1 MGSDEV=/dev/vdb mgs_MOUNT="/data/dvtrack302:mgmt1" mgsfailover_HOST=192.168.200.2 MGSNID=192.168.200.1@tcp:192.168.200.2@tcp',
        'Check MGS options');
    DEBUG "MDS OPT:" . $exe->mdsopt;
    is( $exe->mdsopt,
        #        'NETTYPE=tcp mds1_HOST=192.168.200.3 MDSDEV1=/dev/vdb mds_HOST=192.168.200.3 MDSDEV=/dev/vdb ' .
        #        'mds1failover_HOST=192.168.200.4 mdsfailover_HOST=192.168.200.4 mds2_HOST=192.168.200.4 MDSDEV2=/dev/vdc ' .
        #        'mds2failover_HOST=192.168.200.3 mds3_HOST=192.168.200.2 MDSDEV3=/dev/vdc mds3failover_HOST=192.168.200.1 MDSCOUNT=3',
        'NETTYPE=tcp mds1_HOST=192.168.200.3 MDSDEV1=/dev/vdb mds1_MOUNT="/data/dvtrack303:md1" '
            .'mds_HOST=192.168.200.3 MDSDEV=/dev/vdb mds1failover_HOST=192.168.200.4 '
            .'mdsfailover_HOST=192.168.200.4 mds2_HOST=192.168.200.4 MDSDEV2=/dev/vdc '
            .'mds2_MOUNT="/data/dvtrack303:md2" mds2failover_HOST=192.168.200.3 '
            .'mds3_HOST=192.168.200.2 MDSDEV3=/dev/vdc mds3_MOUNT="/data/dvtrack303:md3" '
            .'mds3failover_HOST=192.168.200.1 MDSCOUNT=3',
        'Check MDS OPT' );

    DEBUG "OSS OPT:" . $exe->ossopt;
    is(
        $exe->ossopt,
        #        'ost1_HOST=192.168.200.6 OSTDEV1=/dev/vdb ost1failover_HOST=192.168.200.5 ost2_HOST=192.168.200.6 OSTDEV2=/dev/vdc ' .
        #        'ost2failover_HOST=192.168.200.5 ost3_HOST=192.168.200.5 OSTDEV3=/dev/vdd ost3failover_HOST=192.168.200.6 ' .
        #        'ost4_HOST=192.168.200.5 OSTDEV4=/dev/vde ost4failover_HOST=192.168.200.6 OSTCOUNT=4',
        'ost1_HOST=192.168.200.6 OSTDEV1=/dev/vdb ost1_MOUNT="/data/dvtrack304:md1"'
            .' ost1failover_HOST=192.168.200.5 ost2_HOST=192.168.200.6 OSTDEV2=/dev/vdc'
            .' ost2_MOUNT="/data/dvtrack304:md2" ost2failover_HOST=192.168.200.5 ost3_HOST=192.168.200.5'
            .' OSTDEV3=/dev/vdd ost3_MOUNT="/data/dvtrack304:md3" ost3failover_HOST=192.168.200.6'
            .' ost4_HOST=192.168.200.5 OSTDEV4=/dev/vde ost4_MOUNT="/data/dvtrack304:md4"'
            .' ost4failover_HOST=192.168.200.6 OSTCOUNT=4',
        'Check OSS OPT'
    );

    DEBUG "CLNT OPT:" . $exe->clntopt;
    is( $exe->clntopt,
        'CLIENTS=192.168.200.7 RCLIENTS="192.168.200.8"',
        'Check Clients options' );
};

sub test_check_cmd_ib_generation {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemibcfg.yaml');

    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareEnvOpts;
    DEBUG "MDS OPT:" . $exe->mdsopt;
    is( $exe->mdsopt, 'NETTYPE=o2ib mds1_HOST=mds MDSDEV1=/dev/loop0 mds_HOST=mds MDSDEV=/dev/loop0 MDSCOUNT=1',
        'Check MDS OPT for o2ib nettype' );
};

sub test_check_cmd_clnonly_generation {
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/testsystemclnonlycfg.yaml');

    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $exe = Xperior::Executor::LustreTests->new();
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareEnvOpts;
    DEBUG "MDS OPT:" . $exe->mdsopt;
    is( $exe->mdsopt, 'MGSNID=192.168.3.12@tcp:192.168.3.13@tcp:/testfs CLIENTONLY=1',
        'Check MDS OPT for client only' );

    DEBUG "OSS OPT:" . $exe->ossopt;
    is($exe->ossopt,' ','Check OSS OPT for client only');

    DEBUG "CLNT OPT:" . $exe->clntopt;
    is( $exe->clntopt,
        'CLIENTS=lclient RCLIENTS="mds"',
        'Check Clients options' );
};


sub test_check_cmd_processlogs {
    my $exe = Xperior::Executor::LustreTests->new();
    Xperior::Executor::Roles::StoreSyslog->meta->apply($exe);
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $fr = $exe->processLogs('t/testout/9.stdout.log');
    is( $fr, $exe->FAILED, "Failed result" );
    like(
        $exe->yaml->{messages},
        qr/Cannot list lctl logs files\[\/tmp\/test_logs\/1365001494\/replay-dual.test_9.*.1365001544.log\]/,
        'Check failure messages'
    );
    my $file1    = '/tmp/replay-dual.test_9.1.log';
    my $teststr1 = 'xperior test file 1';
    my $file2    = '/tmp/replay-dual.test_9.2.log';
    my $teststr2 = 'xperior test file 2';
    my $file3    = '/tmp/recovery-small..1.1375655932.log';
    my $teststr3 = 'xperior test file 3';

    write_file( $file1, $teststr1 ) or confess "Can't create $file1: $!";
    write_file( $file2, $teststr2 ) or confess "Can't create $file2: $!";
    write_file( $file3, $teststr3 ) or confess "Can't create $file3: $!";

    remove_tree('/tmp/test_wd');
    make_path('/tmp/test_wd/sanity/');
    $exe->init( $test, \%options, $cfg );
    $fr = $exe->processLogs('t/testout/9.stdout.log.realfile');

    my $resultstr1 =
        read_file('/tmp/test_wd/sanity/1a.lctllog.replay-dual.test_9.1.log');
    is( $teststr1,              $resultstr1, 'Compare files #1' );
    is( $exe->yaml->{messages}, '',          'Check that messages empty#1' );

    my $resultstr2 =
        read_file('/tmp/test_wd/sanity/1a.lctllog.replay-dual.test_9.2.log');
    is( $teststr2,              $resultstr2, 'Compare files #2' );
    is( $exe->yaml->{messages}, '',          'Check that messages empty#2' );

    #$exe->init( $test, \%options, $cfg );
    $fr = $exe->processLogs('t/testout/26a.stdout.log');

    my $resultstr3 =
        read_file('/tmp/test_wd/sanity/1a.lctllog.recovery-small..1.1375655932.log');
    is( $teststr3,              $resultstr3, 'Compare files #3' );
    is( $exe->yaml->{messages}, '',          'Check that messages empty#3' );

    unlink $file1;
    unlink $file2;
    unlink $file3;
};

sub test_check_cmd_systemlog_parsin {
    my $exe = Xperior::Executor::LustreTests->new();
    Xperior::Executor::Roles::StoreSyslog->meta->apply($exe);
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $mclient    = $exe->_getMasterNode();
    my $mclientobj = $exe->env->getNodeById( $mclient->{'node'} );
    my $connector  = $mclientobj->getRemoteConnector;

    $exe->processSystemLog( $connector, 't/testout/23b.messages.vm1.log' );
    like( $exe->yaml->{messages},
        qr/Cannot copy log file \[\/tmp\/lustre-log\.1360606441\.2365\]/,
        'Check messages' );

    my $file    = '/tmp/xp_test_file';
    my $teststr = 'xperior test file';
    write_file( $file, $teststr ) or confess "Can't create $file: $!";

    remove_tree('/tmp/test_wd');
    make_path('/tmp/test_wd/sanity/');
    $exe->init( $test, \%options, $cfg );
    $exe->processSystemLog( $connector,
        't/testout/23b.messages.vm1.log.realfile' );
    DEBUG Dumper $exe->yaml;
    my $resultstr = read_file('/tmp/test_wd/sanity/1a.dump.0.log');
    is( $teststr,               $resultstr, 'Compare files' );
    is( $exe->yaml->{messages}, '',         'Check that messages empty' );
    unlink $file;
};

sub test_check_cmd_processlogs_1 {
    my $exe  = Xperior::Executor::LustreTests->new();
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );


    my $res = $exe->processLogs('t/testout/sanity.1a.stdout.log');
    is( $res, 0, 'Check PASSED status' );

    $res = $exe->processLogs('t/testout/sanity.68a.stdout.log');
    is( $res, 1, 'Check SKIPPED status' );

    $res = $exe->processLogs('t/testout/sanity.1a.f.stdout.log');
    is( $res, 100, 'Check NOTSET status' );

    $res = $exe->processLogs('t/testout/recovery-small.24b.stdout.log');
    is( $res, 0, 'Check PASSED status, special case "DEBUG MARKER"' );

    $res = $exe->processLogs('t/testout/fail_client_mds.stdout.log');
    is( $res, 0, 'Check PASSED status with word "FAIL" as part of stdout' );

    $res = $exe->processLogs('t/testout/flock-nfs.1a.stdout.log');
    is( $res, 10, 'Check FAILED status with word "TPASS" as part of stdout' );

    $res = $exe->processLogs('t/testout/sanity-scrub.1c.stdout.log');
    is( $res, 100, 'Check NOTSET status with test result as PASSED but without "test complete," string' );

    $res = $exe->processLogs('t/testout/conf-sanity.28.stdout.log');
    is( $res, 1, 'Check SKIPPED status for multiple test results in same stdout' );

};

sub test_check_cmd_processlogs_2 {
    my $exe  = Xperior::Executor::LustreTests->new();
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );

    my $res = $exe->processLogs('t/testout/1.stdout.log');
    $res = $exe->processLogs('t/testout/1.stderr.log');
    is( $res, 0, 'Check PASSED status' );
}

sub test_check_result_yaml {
    my $exe  = Xperior::Executor::LustreTests->new();
    my $test = Xperior::Test->new;
    $test->init( \%th, \%gh );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    my $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    $exe->init( $test, \%options, $cfg );
    $exe->_prepareCommands;
    $exe->execute;

    is( $exe->yaml->{'client_count'}, '2', 'Check client count' );
};

1;
