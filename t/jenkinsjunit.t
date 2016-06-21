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

package jenkinsjunit;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Slurp;

use Xperior::Reports::JenkinsJunit;
my $wd = '/tmp/test_wd/';
my $jwd = "$wd/junittest";
my $resdir = '/tmp/test_jjunit';
my $options;
startup _startup => sub {
    Log::Log4perl->easy_init( { level => $DEBUG } );
};
setup _setup       => sub {
    remove_tree('/tmp/test_wd');
    remove_tree($resdir);
    make_path($jwd);
    my %o = ();
    $options = \%o;
    $options->{workdir} = $wd;
    $options->{jjunit}  = $resdir;
};
teardown _teardown => sub {
    #remove_tree('/tmp/test_wd');
    #remove_tree('/tmp/test_jjunit');
};
shutdown _shutdown => sub { };

########################################
test
  plan      => 7,
  ePassChecks => sub {
    my $wd  = '--workdir=$wd';
    my $cfg = '--config=t/testcfgs/localtestsystemcfg.yaml';
    for my $file (glob 't/checkhtmldata/sanity/0.*') {
        fcopy ($file, $jwd) or confess $!;
    }
    my $junitReport = Xperior::Reports::JenkinsJunit->new();
    $junitReport->generateJunit($options, 'junittest');

    ok(-e "$resdir/junittest.junit",
        "Check file [$resdir/junittest.junit] existence");

    my $data = read_file("$resdir/junittest.junit", err_mode => 'carp' );
    ok((scalar(split(/\n/,$data) >10 )), 'Check size');

    ok($data =~ m/name="xperior"/, 'Check pass xml  N1' );
    ok($data =~ m/tests="1"/, 'Check xml  N2' );
    ok($data =~ m/classname="junittest.0"/, 'Check pass xml  N3' );
    ok($data =~ m/<system-err>mft67: which: no l_getgroups in/,
         'Check pass xml  N4' );
    ok($data =~ m/<system-out>Logging to local directory:/,
         'Check pass xml  N5' );
};

test
  plan      => 10,
  fSkipChecks => sub {
    my $wd  = '--workdir=$wd';
    my $cfg = '--config=t/testcfgs/localtestsystemcfg.yaml';
    for my $file (glob 't/checkhtmldata/sanity/101a.*') {
        fcopy ($file, $jwd) or confess $!;
    }
    my $junitReport = Xperior::Reports::JenkinsJunit->new();
    $junitReport->generateJunit($options, 'junittest');

    ok(-e "$resdir/junittest.junit",
        "Check file [$resdir/junittest.junit] existence");

    my $data = read_file("$resdir/junittest.junit", err_mode => 'carp' );
    ok((scalar(split(/\n/,$data) >10 )), 'Check size');

    ok($data =~ m/name="xperior"/, 'Check skip xml N1' );
    ok($data =~ m/tests="1"/, 'Check xml N2' );
    ok($data =~ m/skipped="1"/, 'Check xml N2' );
    ok($data =~ m/<system-err><\/system-err>/,
         'Check skip xml N4' );
    ok($data =~ m/<system-out>/,
         'Check skip xml N5' );
    ok($data =~ m/<\/system-out>/,
         'Check skip xml N6' );
    ok($data =~ m/measurement/,
         'Check skip xml N7' );
    ok($data =~ m/value/,
         'Check skip xml N8' );

};

test
  plan      => 3,
  kRTP_1697_Checks => sub {
    my $wd  = '--workdir=$wd';
    my $cfg = '--config=t/testcfgs/localtestsystemcfg.yaml';
    for my $file (glob 't/checkjunitdata/RPT-1697/56w.*') {
        fcopy ($file, $jwd) or confess $!;
    }
    my $junitReport = Xperior::Reports::JenkinsJunit->new();
    $junitReport->generateJunit($options, 'junittest');

    ok(-e "$resdir/junittest.junit",
        "Check file [$resdir/junittest.junit] existence");

    my $data = read_file("$resdir/junittest.junit", err_mode => 'carp' );
    ok((scalar(split(/\n/,$data) >10 )), 'Check size');
    ok($data =~ m/d0\.sanity\/d56w\/\.\?\:VOLATILE\:\:/,
         'Check skip xml N5 reg' );
};

test
  plan      => 3,
  lRTP_2068_Checks => sub {
    my $wd  = '--workdir=$wd';
    my $cfg = '--config=t/testcfgs/localtestsystemcfg.yaml';
    for my $file (glob 't/checkjunitdata/RTP-2068/18.*') {
        print "$file\n";
        fcopy ($file, $jwd) or confess $!;
    }
    my $junitReport = Xperior::Reports::JenkinsJunit->new();
    $junitReport->generateJunit($options, 'junittest');

    ok(-e "$resdir/junittest.junit",
        "Check file [$resdir/junittest.junit] existence");

    my $data = read_file("$resdir/junittest.junit", err_mode => 'carp' );
    ok((scalar(split(/\n/,$data) >10 )), 'Check size no_stdout');
    ok($data =~ m/No stdout data found/,
         'Check xml no sdtout' );
};

test
    plan      => 2,
    m_subtests_Checks => sub {
        my $wd  = '--workdir=$wd';
        my $cfg = '--config=t/testcfgs/localtestsystemcfg.yaml';
        for my $file (glob 't/checkjunitdata/subtests/*.*') {
            print "$file\n";
            fcopy ($file, $jwd) or confess $!;
        }
        my $junitReport = Xperior::Reports::JenkinsJunit->new();
        $junitReport->generateJunit($options, 'junittest');
        ok(-e "$resdir/junittest.junit",
            "Check file [$resdir/junittest.junit] existence");
        my $data = read_file("$resdir/junittest.junit", err_mode => 'carp' );
        ok($data =~ m/2iozone-small\.client1\.stdout\.log/,
            'Check subtest record' );

    };

jenkinsjunit->run_tests;
