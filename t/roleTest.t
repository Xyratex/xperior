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
# Copyright 2013 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

#!/usr/bin/perl -w
package roleTest;
use strict;
use Test::Able;
use Test::More;
use Xperior::Core;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Moose;
use Module::Load;
use File::Slurp;
use File::Path qw(make_path remove_tree);

use Xperior::Executor::Noop;
use Xperior::Test;


my %options = (
    workdir => '/tmp/test_wd',
);

my %th = (
      id  => 1,
      inf => 'more info',
);
my %gh = (
      executor  => 'Xperior::Executor::Noop',
      groupname => 'sanity',
        );
my $logfile = '/tmp/xp.test.log';
my $test;
my $exe;
my $cfg;
startup         some_startup  => sub {
};
setup           some_setup    => sub {
    remove_tree('/tmp/test_wd');
    unlink($logfile);
    my $testcore =  Xperior::Core->new();
    $testcore->options(\%options);
    $cfg = $testcore->loadEnv('t/testcfgs/testsystemcfg.yaml');
    $test = Xperior::Test->new;
    $test->init(\%th,\%gh);
    Log::Log4perl->init(\ qq{
        log4perl.rootLogger                = DEBUG, Logfile, Screen
        log4perl.appender.Logfile          = Log::Log4perl::Appender::File
        log4perl.appender.Logfile.filename = /tmp/xp.test.log
        log4perl.appender.Logfile.layout = Log::Log4perl::Layout::SimpleLayout
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr  = 0
        log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
    });
    $exe = Xperior::Executor::Noop->new();
    $exe->init($test, \%options, $cfg);
};


test plan =>3, dCheckSimple => sub{
    use RoleTest;
    RoleTest->meta->apply($exe);
    $exe->execute();
    DEBUG Dumper $exe->yaml;
    #checks
    is($exe->teststatus(),'pass','check execution complete');
    my @lines = read_file( $logfile ) ;
    my @check1 = grep(/AFTER\[beforeExecute\]\:RoleTest/, @lines);
    if ($check1[0] =~ m/elapsed\s\[(\d)\]/){
        is($1,$RoleTest::test_sleep_time_before,'Check before');
    }else{
        fail('Unxpected string found:'.$check1[0]);
    }
    my @check2 = grep(/AFTER\[afterExecute\]\:RoleTest/, @lines);
    if ($check2[0] =~ m/elapsed\s\[(\d)\]/){
        is($1,$RoleTest::test_sleep_time_after,'Check after');
    }else{
        fail('Unxpected string found:'.$check2[0]);
    }

};

test plan =>5, gTwoRolesCheck => sub{
    use RoleTest;
    RoleTest->meta->apply($exe);
    use RoleTest1;
    RoleTest1->meta->apply($exe);
    $exe->execute();
    DEBUG Dumper( $exe->yaml);
    #checks
    my @lines = read_file( $logfile );
    my @filtereddata;
    foreach my $line (@lines){
        if($line =~ /AFTER|BEFORE/){
            push @filtereddata,$line;
        }
    }
    like($filtereddata[0], '/BEFORE\[beforeExecute\]\:RoleTest1/',
        'Role1 before');
    like($filtereddata[1], qr/AFTER\[beforeExecute\]\:RoleTest1.*elapsed \[6\]/,
        'Role1 after end');
    like($filtereddata[3], qr/AFTER\[beforeExecute\]\:RoleTest\[.*elapsed\ \[1\]/,
        'Role after end');
    like($filtereddata[5], qr/AFTER\[afterExecute\]\:RoleTest\[.*elapsed\ \[3\]/,
        'Role1 before end');
    like($filtereddata[7], qr/AFTER\[afterExecute\]\:RoleTest1\[.*elapsed\ \[5\]/,
        'Role1 load');
    DEBUG "\n".Dumper( @filtereddata);
};
#########################################
roleTest->run_tests;
