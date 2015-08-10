#!/usr/bin/env perl
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
# Please  visit http://www.xyratex.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

Xperior

=head1 SYNOPSIS

    xper --action <run|list|generate-html|generate-jjunit> [--continue] [<options>]

=head1 DESCRIPTION

The application executes different specially wrapped tests via Xperior harness.
The application reads yaml tests descriptions, checks environment, reads and gathers
cluster configuration, runs tests based on found configuration,
collects logs and saves a report.

=head1 OPTIONS

=over 2

=item --action=<run|list|generate-jjunit|generate-html>

=over 6

=item run

Execute tests selected in configuration and filters.

=item list

Print list of tests which will be ready to execute considering configuration
and filters.

=item generate-html

Generate html report based on exist workdir with execution results.

=item generate-jjunit

Generate Jenkins Junit report based on existing workdir with execution results.
Option --jjunit must be set also.

=back

=item --help

Print usage help

=item --man

Print long help

=item --cmdout

Show test cmd output. Default - no.

=item --tap

Generate tap files in working directory

=item --html

Generate html report in working directory: C<report/report.html>

=item --jjunit=<path>

Generate Jenkins Junit report in <path> directory.

=item --continue

Continue execution in specified working directory. Execution is continued
from the next test after last written one which is possibly not finished.
Report the results. If L<--continue> is not set, then the previous results
in the working directory are overwritten.

=item --random

Execute tests in random order

=item --multirun

Optional, defines how much times every test should be executed.
Alternatively, could be set for specific test via test parameter
in test descriptor:

    - id       : test1
    .....
    multirun : 10

Command line option overrides test parameter. After end of execution
for multiplied tests will be generated results with with 'id' ends '__x',
where is 'x' - number in series.
E.g.
    tests1_0.yaml (for first execution)
    tests1_1.yaml
    ...........
    tests1_5.yaml (for 5-th execution)


=item --skipnodeinfo

TBI

=item --extopt=name:value

Additional options which will be stored in test results.
You can use this option several times to pass more than one parameter.
Overrides values taken from external options' file
if used simlutaneousely with L<--extop-file> option.
For details, see L<--extopt-file>.

=item --extopt-file=<path>

Read external options from file in YAML format.
The file should contain 'extoptions' key under which
other options should be provided. See example:

	---
	extoptions:
	  branch: xyratex
	  executiontype: weekly

To override options with custom values from command line, please,
refer L<--extopt> option.

=back


=head2 Configuration

=over 2

=item --useproccfg

TBD

=item --config=<path>

path to yaml config file, syntax TBD here!

=item --workdir=<path>

Working directory where test log and results will be saved

=item --testdir=<path>

Directory where are test descriptors yaml files

=back

=head2 Filters

=head3 Exclude/include lists

Each test is defined by its name and test group.
It is possible to use regular expression which will be used for string comparison.
Symbols after '#' are ignored. Sample:

	replay-dual.* #match to any replay-dual continue
	sanity/a1
	#comment too

=over 2

=item --excludelist

List of tests for exclude from execution. These tests will not be executed,
no status or report will be generated. See syntax definition above.

=item --includelist

List of tests for execution. Only tests in the list will be executed.
Same syntax as exclude list, see above.

=item --includeonly

List of test for execution from command line. Use this parameter twice or more
for many tests. Exclude/include lists parameters is ignored if this key
pointed. Test must be pointed as <test group>/<test name>. See also
include/exclude list format above.


=item --skiptag=<tags>

List of tags which will be skipped. No mask or regexp allowed.
Use this parameter twice or more for many tag exclusion.
Ignored if L<--includeonly> set.

=back

=head2 Logging level

=over 2

=item --debug

'debug' log level

=item --info

'info'  log level

=item --error

'error' log level (default)

=item --log-file=<path>

Set file path where logs will be saved. By default, logs are printed to STDOUT.

=back

=head1 EXIT CODES

=over 4

=item 0

Execution done successfully, all results ready

=item 10

Execution done because of detected nodes crash or network problem

=item 11

Execution done because of failure of tests which are in critical tests list
=item 12

Execution done because test have enabled 'exitafter' property. It means that some actions must be done after test execution.

=item 19

Original configuration cannot pass check

=back

=head1 RUNNING INTERNAL TESTS

TBD

=head1 AUTHOR

ryg, E<lt>Roman_Grigoryev@xyratex.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) Xyratex, 2011

=head1 SEE ALSO

See Xperior harness User Guide for detail of system configuration.

=cut



use strict;
use warnings;
use English;
use Getopt::Long;
use Carp;
use Pod::Usage;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Basename;
use File::Path qw/make_path/;
use Log::Log4perl qw(:easy);


my $XPERIORBASEDIR;
BEGIN {

    $XPERIORBASEDIR = dirname(Cwd::abs_path($PROGRAM_NAME));
    push @INC, "$XPERIORBASEDIR/../lib";

};

use Xperior::Core;

$|=1;

my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my $configfile = "";
my $mode       = "";
my @suites;
my @skiptags;
my @includeonly;
my @extopt;
my $extoptfile;
my $includelist ='';
my $excludelist ='';
my $task       = "";
my $flist      = "";
my $workdir    = '';
my $testdir    = 'testds';
my $debug      = 0;
my $info       = 0;
my $error      = 0;
my $cmdout     = 0;
my $action=undef;
my $helpflag;
my $manflag;
my $continue;
my $tap;
my $html;
my $jjunit  = '';
my $logfile = 'xperior.log';
my $multirun;
my $random;
my $logname = '';

GetOptions(
    "config:s"       => \$configfile,
    "mode:s"         => \$mode,
    "suites=s@"      => \@suites,
    "skiptag=s@"     =>  \@skiptags,
    "includeonly=s@" => \@includeonly,
    "extopt=s@"      => \@extopt,
    "extopt-file=s"  => \$extoptfile,
    "tests:s"        => \$task,
    "excludelist:s"  => \$excludelist,
    "includelist:s"  => \$includelist,
    "flist:s"        => \$flist,
    "random!"        => \$random,
    "multirun:i"     => \$multirun,
    "workdir:s"      => \$workdir,
    "testdir:s"      => \$testdir,
    "debug!"         => \$debug,
    "info!"          => \$info,
    "error!"         => \$error,
    "cmdout!"        => \$cmdout,
    "help!"          => \$helpflag,
    "man!"           => \$manflag,
    "action:s"       => \$action,
    "continue!"      => \$continue,
    "tap!"           => \$tap,
    "html!"          => \$html,
    "jjunit:s"       => \$jjunit,
    "log-file:s"     => \$logfile,
);

pod2usage(-verbose => 1) if ( ($helpflag) || ($nopts) );

pod2usage(-verbose => 2) if ($manflag);
#check test description configuration existence
if((defined $action) &&($action ne '') ){
    unless (($action eq 'run')
    || ( $action eq 'list')
    || ( $action eq 'generate-jjunit')
    || ( $action eq 'generate-html')){
        print "Incorrect action set : $action\n";
        pod2usage(3);
    }
}else{
    $action = 'run';
}

if($workdir){
   if (! -d $workdir) {
       make_path( $workdir );
   }
       $logname = "$workdir/$logfile";
}
else{
    print "No workdir specified, please set --workdir  \n";
    exit 1;
}

Log::Log4perl->easy_init({ level=>$DEBUG,
               file     => ">$logname" },
               { level    => $DEBUG,
               file     => "STDOUT",
               filter => '' },
               );

if (-e $configfile) {
    INFO "Configuration file is [$configfile]";
} elsif ( $action eq 'generate-html'){
    INFO "Configuration file is not needed in this mode";
}else{
    confess "Cannot find configuration file [$configfile]" ;
}

if (-d $testdir) {
    INFO "Test directory [$testdir] found";
} elsif ( $action eq 'generate-html'){
    INFO "Test directory is not needed in this mode";
}else{
    confess "Cannot find test directory [$testdir]" ;
}

if ( !$debug ){
    my %abn = %Log::Log4perl::Logger::APPENDER_BY_NAME;
    my $appender = $abn{'app002'};

    my $type = 'Log::Log4perl::Filter::LevelMatch';
    eval "require $type" or confess "Require of $type failed ($!)";
    my $level='ERROR';
    if ($info){
    $level='INFO';
    }
    my $filter = $type->new(name => 'filter',
         LevelToMatch  => $level,
         AcceptOnMatch => 'true',
       );
    $filter->register();
    $appender->filter($filter);
    ERROR  'Default debug mode is on , full log in '.$logname;
}


if( $action eq 'run'){
    if (-d $workdir) {
        INFO "Test directory [$workdir] found, overwriting old ".
             "results if --continue is not set";
    }else{
        INFO "No workdir directory [$workdir] found, create it.";
        my $number_of_created_dir = make_path($workdir, {verbose => 1});
        unless( $number_of_created_dir){
            print "Cannot create workdir [$workdir]\n";
            exit 10;
        }
    }
}

my %options = (
    xperiorbasedir => "$XPERIORBASEDIR/../lib",
    testdir  => $testdir,
    workdir  => $workdir,
    cmdout   => $cmdout,
    skiptags => \@skiptags,
    excludelist => $excludelist,
    includelist => $includelist,
    includeonly => \@includeonly,
    action   => $action,
    continue => $continue,
    random   => $random,
    configfile => $configfile,
    tap      => $tap,
    html     => $html,
    jjunit   => $jjunit,
    extopt   => \@extopt,
    extoptfile => $extoptfile,
);

$options{'multirun'}=$multirun if($multirun);
my $testcore =  Xperior::Core->new();
$testcore->run(\%options);

__END__

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 only,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License version 2 for more details (a copy is included
in the LICENSE file that accompanied this code).

You should have received a copy of the GNU General Public License
version 2 along with this program; If not, see http://www.gnu.org/licenses



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut


