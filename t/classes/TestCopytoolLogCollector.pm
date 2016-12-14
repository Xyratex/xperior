package test_copytool_log_collector;

use strict;
use warnings;
use Test::Class::Moose;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Log::Log4perl qw(:easy);
use File::Slurp;
use File::Copy;

use Xperior::Core;
use Xperior::Executor::Roles::CopytoolLogCollector;
use Xperior::Executor::Noop;
use Xperior::Test;
use Xperior::Executor::LustreTests;


my $console_file = '/tmp/xp_local_console_file';

my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
    id  => 20,
    inf => 'more info',
);

my %gh = (
    executor  => 'Xperior::Executor::XTest',
    groupname => 'hsm-sanity',
);

my $exe;
my $cfg;
my $sample_path = 't/testout/test_logs.20/';
my $tf_workdir  = '/tmp/test_logs/';
my $wd = '/tmp/test_wd/';
my $suite  = 'hsm-sanity';
my $stdout = 't/testout/20.stdout.log';

sub test_setup {
    my $test = shift;
    $test->next::method;
    # more setup
    Log::Log4perl->easy_init($DEBUG);
    remove_tree( $wd );
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    ###$cfg = $testcore->loadEnv('xperior.config.txt');
    make_path($tf_workdir);
    make_path("$wd/$suite/");
    dircopy($sample_path,$tf_workdir);
    copy($stdout,"$wd/$suite/");

}
sub test_check_copytool_collection {
    write_file( $console_file, '' )
        or confess "Can't create $console_file: $!";

    my $test   = shift;
    $test = Xperior::Test->new();
    $test->init( \%th, \%gh );
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::CopytoolLogCollector->meta->apply($exe);
    $exe->init( $test, \%options, $cfg );
    $exe->execute;
    #print Dumper $exe->yaml->{log};
    is(-e '/tmp/test_wd/hsm-sanity/20.sanity-mlhsm.copytool_log.'
            .'vmc-rekvm-dm-1-1.xy01.xyratex.com.log.client1.log',
        1, 'Check attached copytoollog collector');
    DEBUG '--------------------------------------';

    #cleanup for Noop
    my $mclient    = $exe->_getMasterNode();
    my $mclientobj = $exe->env->getNodeById($mclient->{'node'});
    my $node  = $mclientobj->getRemoteConnector();
    $node->masterprocess->kill();

}

1;