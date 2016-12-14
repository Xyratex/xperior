#!/usr/bin/perl

use strict;
use warnings;
$| = 1;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use File::Path qw(make_path mkpath remove_tree);
use File::chdir;
use File::Copy;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
#use List::Util 'max';
use Env qw(TMP RPM_TOPDIR);
use Carp;
my $BUILDDIR="$CWD/rpms/";
my $WD=$CWD;
my $SD  = "${BUILDDIR}/SOURCES";
my $SPD = "${BUILDDIR}/SPECS/";
#$CWD='src';
my $perldir   = $ENV{PERLBIN} || confess "No PERLBIN set";
my $xpextlibs  = $ENV{XPEXTLIBS} || DEBUG "XPEXTLIBS not found";
#'/opt/ActivePerl-5.14/';
my $covercmd  = "$perldir/bin/cover";
my $testcmd   = "$perldir/bin/prove  -v --timer --normalize --formatter=TAP::Formatter::JUnit -l ";
my $testopt   = "PERL5OPT=-MDevel::Cover=+inc PERL5LIB=lib:t/lib:$xpextlibs";
my $criticcmd = "perlcritic";
runEx("$criticcmd  -3  bin  lib/Xperior > $WD/critic.txt");
runEx("$covercmd --delete");
#enable testing for limited number of t
runEx("$testopt $testcmd   t/ielists.t                   >  $WD/ielists.junit");
runEx("$testopt $testcmd   t/core.t                      >  $WD/core.junit");
runEx("$testopt $testcmd   t/executors.t                 > $WD/executors.junit");
runEx("$testopt $testcmd   t/sshprocess.t                > $WD/sshprocess.junit");
runEx("$testopt $testcmd   t/launcher.t                  > $WD/launcher.junit");
runEx("$testopt $testcmd   t/lib-xperior-utils-shell.t   > $WD/t/lib-xperior-utils-shell.junit");
runEx("$testopt $testcmd   t/utils.t                     > $WD/utils.junit");
runEx("$testopt $testcmd   t/checkyaml.t                 > $WD/checkyaml.junit");
runEx("$testopt $testcmd   t/lib-xperior-test.t          > $WD/lib-xperior-test.t");
runEx("$testopt $testcmd   t/roleLoader.t                > $WD/t/roleLoader.t");
runEx("$testopt $testcmd   t/roleTest.t                  > $WD/t/t/roleTest.t");
runEx("$testopt $testcmd   t/roleStoreSyslog.t           > $WD/rolestoresyslog.junit");
runEx("$testopt $testcmd   t/compatlustretests.t         > $WD/compatlustretests.junit");
runEx("$testopt $testcmd   t/lustresingleexec.t          > $WD/lustresingleexec.junit");
runEx("$testopt $testcmd   t/roleReformatBefore.t        > $WD//roleReformatBefore.junit");
runEx("$testopt $testcmd   t/roleStartMpdbootBefore.t    > $WD/roleStartMpdbootBefore.junit");
runEx("$testopt $testcmd   t/roleCustomLogCollector.t    > $WD/roleCustomLogCollector.junit");
runEx("$testopt $testcmd   t/executorLustreHA.t          > $WD/executorLustreHA.junit");
runEx("$testopt $testcmd   t/roleVmcoreGenerator.t       > $WD/roleVmcoreGenerator.junit");
runEx("$testopt $testcmd   t/simpletest.t                > $WD/simpletest.junit");
runEx("$testopt $testcmd   t/testenv.t                   > $WD/t/testenv.t");
runEx("$testopt $testcmd   t/example_xperior_test.t      > $WD/t/example_xperior_test.t");
runEx("$covercmd");
runEx("$covercmd -report clover");
#thereaded, calculate separately 
$testopt   = "PERL5LIB=lib:t/lib:$xpextlibs";
runEx("$testopt $testcmd   t/executorMultiNodeSingleprocess.t  > $WD/executorMultiNodeSingleprocess.junit");




#js/mongo tests
#runExternalApp("PERL5LIB=lib:mongo/lib $testcmd  mongo/t/mapreduce.t  > $WD/mongo.junit");


#$CWD="$WD/src";
runEx('make clean');
mkpath ('html') or confess 'Cannot create doc folder';
runEx('bin/gendocs.pl',1);



