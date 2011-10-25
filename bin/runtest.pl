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
my $testdir    ='testds';
my $debug      = 0;
my $info       = 0;
my $error      = 0;
my $cmdout     = 0;
my $helpflag;
GetOptions(
    "config:s"     => \$configfile,
    "mode:s"       => \$mode,
    "suites=s@"    => \@suites,
    "tests:s"      => \$task,
    "exclude:s"    => \$helpflag,
    "flist:s"      => \$flist,
    "workdir:s"    => \$workdir,
    "testdir:s"    => \$testdir,
    "debug!"       => \$debug,
    "info!"        => \$info,
    "error!"       => \$error,
    "cmdout!"      => \$cmdout,
);

my $hm = <<"HM";
Help message

--useproccfg    : TBD
--config        : TBD path to yaml config file

--workid        : working dir where test log and results will be saved
--testdir       : directory where are test descriptors yaml files
--contine       : TBD

Framework logging level 
--debug         : 'debug' log level
--info          : 'info'  log level
--error         : 'error' log level (default)

--cmdout        : show test cmd output. Default - no.

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

#check test description configuration existence
if (-d $testdir) {
 INFO "Test directory [$testdir] found";
}else{
    confess "Cannot find test directory [$testdir]" ;
}


unless(defined($workdir)){
    print "No workdir specified\n";
    exit 1;
}

if (-d $workdir) {
 INFO "Test directory [$workdir] found";
}else{                                                
    print "Cannot find test directory [$workdir]\n" ;
    exit 1;
}
        
 my %options = ( 
    testdir => $testdir,
    workdir => $workdir,
    cmdout  => $cmdout,
);

my $testcore =  XTests::Core->new();
$testcore->run(\%options);

__END__
# Documentation for runtest.pl (XTests).

=head1 NAME

runtest.pl is application for executing different tests via XTests harness. This application read yaml tests descriptions,check environmental conditions, read/gather cluster config data and run tests based on it. 

=head1 SYNOPSIS

  export PERL5LIB=....
  perl runtest.pl <parameters>
  Paramaters: 
  run perl runtest.pl 

=head1 DESCRIPTION

TBD!

Stub documentation, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 SEE ALSO


=head1 AUTHOR

ryg, E<lt>Roman_Grigoryev@xyratex.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by ryg, Xyratex

=cut

