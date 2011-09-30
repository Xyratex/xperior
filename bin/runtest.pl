#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  runtest.pl
#
#        USAGE:  ./runtest.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  08/31/2011 06:37:26 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Carp;

use XTests::Core;
$|=1;

my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my $configfile = "";
my $mode       = "";
my @suites;
my $task       = "";
my $flist      = "";
my $workdir    = '';
my $debug      = 0;
my $info       = 0;
my $error      = 0;
my $helpflag;
GetOptions(
    "config:s"     => \$configfile,
    "mode:s"       => \$mode,
    "suites=s@"    => \@suites,
    "tests:s"      => \$task,
    "exclude:s"    => \$helpflag,
    "flist:s"      => \$flist,
    "workdir:s"    => \$workdir,
    "debug!"       => \$debug,
    "info!"        => \$info,
    "error!"       => \$error
);

my $hm = <<"HM";
Help message
--suites        : TBD suite name for compilation; currently supported fxdloader,compiler,media,animation,graphics,webservices
--task          : TBD possible tasks: build,run

--useproccfg    : TBD
--config        : TBD path to yaml config file

--workid        : TBD
--contine       : TBD

Framework logging level 
--debug         : 'debug' log level
--info          : 'info'  log level
--error         : 'error' log level (default)

--help          : print this help message

HM

if ( ($helpflag) || ($nopts) ) {
    print $hm;
    exit(0);
}

if( $debug){
    Log::Log4perl->easy_init($DEBUG);
}
elsif ( $info ) {
    Log::Log4perl->easy_init($INFO);
}
else {
    Log::Log4perl->easy_init($ERROR);
}

my $TESTDIR='testds'; #FIXME get from parameters
#check test description configuration existence
if (-d $TESTDIR) {
 INFO "Test directory [$TESTDIR] found";
}else{
    confess "Cannot find test directory [$TESTDIR]" ;
}

my %options = ( 
 testdir => $TESTDIR,
 );

my $testcore =  XTests::Core->new();
$testcore->run(\%options);

#create configuration
#if ( -e ){
#}


