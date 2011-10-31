#!/usr/bin/perl 
#===============================================================================
#         FILE:  runtest.pl
#
#        USAGE:  ./runtest.pl <options> 
#
#  DESCRIPTION:  Execute XTests narness
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  08/31/2011 06:37:26 PM
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Carp;
use Pod::Usage;

BEGIN {
use Cwd 'abs_path';
    my $p = abs_path($0);
    $p =~s/runtest\.pl$//;
    push @INC, $p.'/../lib/'
};

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
my $manflag;
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
    "help!"        => \$helpflag,
    "man!"         => \$manflag,
);

if ( ($helpflag) || ($nopts) ) {
    pod2usage(2);
}
if ( $manflag) {
    pod2usage( -verbose => 2  );
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
 INFO "Test directory [$workdir] found, overwriting old results";
}else{                                                
    INFO "No workdir directory [$workdir] fount, cretate it.";
    unless( mkdir $workdir){
        print "Cannot create workdir [$workdir]\n";
        exit 10;
    }
}
        
 my %options = ( 
    testdir => $testdir,
    workdir => $workdir,
    cmdout  => $cmdout,
);

my $testcore =  XTests::Core->new();
$testcore->run(\%options);

__END__

=pod

=head1 XTests testing harness 

=head1 NAME

runtest.pl - executing tests via  XTests harness. 

=head1 SYNOPSIS 

    bin/runtest.pl <parameters>
    Paramaters: 
        --useproccfg    : TBD
        --config        : TBD path to yaml config file

        --workdir       : working dir where test log and results will be saved
        --testdir       : directory where are test descriptors yaml files
        --contine       : TBD

    Framework logging level 
        --debug         : 'debug' log level
        --info          : 'info'  log level
        --error         : 'error' log level (default)

        --cmdout        : show test cmd output. Default - no.

        --help          : print usage help
        --man           : print long help


=head1 Description

The application is executing different specially wrapped tests via XTests harness. The application read yaml tests descriptions,check environmental conditions, read/gather cluster configuration and run tests based on it, gather logs and save report.


=head2 Executing internal tests.
TBD


=head1 See also

See XTests harness User Guide for detail of system configuration.

=head1 Author

ryg, E<lt>Roman_Grigoryev@xyratex.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by ryg, Xyratex

=cut

