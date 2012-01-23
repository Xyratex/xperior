#!/usr/bin/perl 
#===============================================================================
#         FILE:  runtest.pl
#
#        USAGE:  ./runtest.pl <options> 
#
#  DESCRIPTION:  Execute XTest narness
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  08/31/2011 06:37:26 PM
#===============================================================================
=pod

=head1 NAME

xtest - execute tests via XTest harness

=head1 SYNOPSIS 

    xtest --action <run|list> [--continue] [<options>]

=head1 DESCRIPTION

The application is executing different specially wrapped tests via XTest
harness. The application read yaml tests descriptions,check environmental
conditions, read/gather cluster configuration and run tests based on it, gather
logs and save report.

=head1 OPTIONS

=over 2

=item --action=<run|list>

=over 6

=item run

Executre tests selected in configuration and filters.

=item list

Print list of tests which will be ready to execution considering configuration
and filters

=back

=item --help

Print usage help

=item --man

Print long help

=item --cmdout

Show test cmd output. Default - no.

=item --tap

Generate also tap files in work directory

=item --continue

Continue execution in specified work directory. Execution is continued from
next test after last found written, possible not completed, report. 
If L<--continue> is not set then previous results in work directory are overwritten.

=item --skipnodeinfo

TBI

=item --extopt=name:value

Additional options which will be stored in test results. use the parameter many
times for many parameters. 
Overrides values taken from external options file 
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

TBD path to yaml config file

=item --workdir=<path>

Working dir where test log and results will be saved

=item --testdir=<path>

Directory where are test descriptors yaml files

=back

=head2 Filters

=head3 Exclude/include lists 

Every tests defined by his name and his test group. 
It is possible to use mask * at the end of string (any continue of the string).
Symbols after '#' are ignored.

=head4 Sample

    sanity/a1
    mdtest* #comment
    #comment too

=over 2

=item --excludelist

List of tests for exclude from execution. These tests will not be executed, 
no status or report will be generated. See syntax definition below.

=item --includelist

List of tests for execution. Only tests in the list will be executed.
Same syntax as exclude list. TBI.

=item --includeonly

List of test for execution from command line. Use this parameter twice or more
for many tests. Exclude/include lists parameters is ignored if this key
pointed. Test must be pointed as <test group>/<test name>. See also
include/exclude list format below.


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

See XTest harness User Guide for detail of system configuration.

=cut



use strict;
use warnings;

use English;
use File::Basename;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Carp;
use Pod::Usage;
use Cwd qw(abs_path);

BEGIN {

    my $XTESTBASEDIR = dirname(Cwd::abs_path($PROGRAM_NAME));
    push @INC, "$XTESTBASEDIR/../lib";

};

use XTest::Core;

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
my $testdir    ='testds';
my $debug      = 0;
my $info       = 0;
my $error      = 0;
my $cmdout     = 0;
my $action=undef;
my $helpflag;
my $manflag;
my $continue;
my $tap;
my $logfile	= undef;   

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
    "log-file:s"     => \$logfile,
);

pod2usage(-verbose => 1) if ( ($helpflag) || ($nopts) );

pod2usage(-verbose => 2) if ($manflag);

if( $debug){
    Log::Log4perl->easy_init({level => $DEBUG, file => defined $logfile ? ">$logfile" : "STDOUT"});
}
elsif ( $info ) {
    Log::Log4perl->easy_init({level => $INFO, file => defined $logfile ? ">$logfile" : "STDOUT"});
}
else {
    Log::Log4perl->easy_init({level => $ERROR, file => defined $logfile ? ">$logfile" : "STDOUT"});
}

#check test description configuration existence
if((defined $action) &&($action ne '') ){
    unless (($action eq 'run') ||( $action eq 'list')){
        print "Incorrect action set : $action\n";
        pod2usage(3);
    }
}else{
    $action = 'run';
}

if (-e $configfile) {
 INFO "Configuration file is [$configfile]";
}else{
    confess "Cannot find configuration file [$configfile]" ;
}

if (-d $testdir) {
 INFO "Test directory [$testdir] found";
}else{
    confess "Cannot find test directory [$testdir]" ;
}


unless(defined($workdir)){
    print "No workdir specified\n";
    exit 1;
}

if( $action eq 'run'){
    if (-d $workdir) {
        INFO "Test directory [$workdir] found, overwriting old results";
    }else{                                                
        INFO "No workdir directory [$workdir] found, create it.";
        unless( mkdir $workdir){
            print "Cannot create workdir [$workdir]\n";
            exit 10;
        }
    }
}
        
 my %options = ( 
    testdir  => $testdir,
    workdir  => $workdir,
    cmdout   => $cmdout,
    skiptags => \@skiptags,
    excludelist => $excludelist,
    includelist => $includelist,
    includeonly => \@includeonly,
    action   => $action,
    continue => $continue,
    configfile => $configfile,
    tap      => $tap,
    extopt   => \@extopt,
    extoptfile => $extoptfile,
);

my $testcore =  XTest::Core->new();
$testcore->run(\%options);

__END__

