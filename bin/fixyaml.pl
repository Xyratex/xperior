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

fixyaml.pl

=head1 SYNOPSIS

 fixyaml.pl --dir <directory>  [<options>]

=head1 DESCRIPTION

Simple program which do few simple modification for yaml files in directory.

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


