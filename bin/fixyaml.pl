#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  fixyaml.pl
#
#        USAGE:  ./fixyaml.pl <options>
#
#  DESCRIPTION:  Do chanages on yaml files

#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  04/03/2012 09:28:31 PM
#===============================================================================
=pod

=head1 NAME

fixyaml.pl - simple program which do few simple modification for yaml files in directory

=head1 SYNOPSIS 

 fixyaml.pl --dir <directory>  [<options>]

=head1 DESCRIPTION

The program can add,change or remove keys and subkeys and its values from yaml files. It specially  created to work with Xperior result files.

Could be used for simple modifications system configurations or test 
descriptors. This sample set role C<GetCoverage> for all files 
in C<workdir>

    bin/fixyaml.pl --dir='workdir' --chkey=roles --value='GetCoverage'


=head1 OPTIONS

=over 2

=item --dir

Directory where placed yaml files. These files will be changed.

=item --rmkey

Remove first-level key or set first level for b<--rmsubkey> parameter

=item --rmsubkey

Remove second-level key

=item --chkey

Add/update first level key or set first level for b<--chsubkey> parameter with value from b<--value> parameter

=item --chsubkey

Add/update second level key

=item --value

Value for b<--chkey> or b<--chsubkey> parameter

=back

=cut

use strict;
use warnings;

use English;
use File::Basename;
use Getopt::Long;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );

use Carp;
use Pod::Usage;
use File::Find;

$| = 1;
use YAML::Syck;

my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my ( $delkey, $delsubkey, $chkey, $chsubkey, $value, $helpflag, $manflag, $dir );

GetOptions(
    "dir:s"      => \$dir,
    "rmkey:s"    => \$delkey,
    "rmsubkey:s" => \$delsubkey,
    "chkey:s"    => \$chkey,
    "chsubkey:s" => \$chsubkey,
    "value:s"    => \$value,
    "help!"      => \$helpflag,
    "man!"       => \$manflag,
    );

pod2usage( -verbose => 1 ) if ( ($helpflag) || ($nopts) );

pod2usage( -verbose => 2 ) if ($manflag);

if ( ( not defined $dir ) || (  $dir eq '' ) ) {
    print "No directory with YAML files set!\n";
    pod2usage(3);
    exit 1;
}

if ( (  (not defined $delkey ) || ( $delkey eq '' ) )
   && ( (not defined $chkey )  || ( $chkey  eq '' ) ) )
{
    print "Correct action is not found!\n";
    pod2usage(3);
    exit 1;
}

if (  (defined $chkey ) && (not defined $value ) )
{
    print "Not set value for change key action!\n";
    pod2usage(3);
    exit 1;
}


my @yamls;

find(
    sub {
        push( @yamls, $File::Find::name )
          if (/\.yaml$/);
    },
    $dir
);

foreach my $file (@yamls){
    DEBUG "Process file '$file'";
    my $data = LoadFile($file) or confess "Cannot load file '$file'";
    if(defined($delkey)){
        if(defined($delsubkey)){
            delete($data->{$delkey}->{$delsubkey});
        }else{
            delete($data->{$delkey});
        }
    }
    if(defined($chkey)){
        if(defined($chsubkey)){
            $data->{$chkey}->{$chsubkey}=$value;
        }else{
            $data->{$chkey}=$value;
        }
    }
    DumpFile($file, $data);
}
INFO "Completed!";
