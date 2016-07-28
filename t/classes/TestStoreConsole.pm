package test_store_console;

use strict;
use warnings;
use Test::Class::Moose;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Log::Log4perl qw(:easy);
use File::Slurp;

use Xperior::Core;
use Xperior::Executor::Roles::StoreConsole;
use Xperior::Executor::Noop;
use Xperior::Test;
use Xperior::Executor::LustreTests;


my $console_file = '/tmp/xp_local_console_file';

my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
    id  => 1,
    inf => 'more info',
);

my %gh = (
    executor  => 'Xperior::Executor::XTest',
    groupname => 'sanity',
);

my $exe;
my $cfg;
my $data = 'test log message 1234567890';

sub test_setup {
    my $test = shift;
    $test->next::method;
    # more setup
    Log::Log4perl->easy_init($DEBUG);
    remove_tree('/tmp/test_wd');
    my $testcore = Xperior::Core->new();
    $testcore->options( \%options );
    $cfg = $testcore->loadEnv('t/testcfgs/localtestsystemcfg.yaml');
    ###$cfg = $testcore->loadEnv('xperior.config.txt');

}
sub test_check_collection {
    write_file( $console_file, '' )
        or confess "Can't create $console_file: $!";

    my $test   = shift;
    $test = Xperior::Test->new();
    $test->init( \%th, \%gh );
    $exe = Xperior::Executor::Noop->new();
    Xperior::Executor::Roles::StoreConsole->meta->apply($exe);
    $exe->init( $test, \%options, $cfg );
    $exe->execute;
    print Dumper $exe->yaml->{log};
    is(-e '/tmp/test_wd/sanity/1.console.client1.log',1, 'Check attached console existence');
    DEBUG `ps afx | grep tail`;
    DEBUG `ps afx | grep sudo`;

}

1;