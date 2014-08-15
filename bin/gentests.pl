#!/usr/bin/perl
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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

xxx.pl

=head1 SYNOPSIS

 xxxl --dir <directory>  [<options>]

=head1 DESCRIPTION

Simple program 

=head1 OPTIONS

=over 2

=item --dir

=back

=cut

use strict;
use warnings;

use English;
use File::Basename;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use YAML qw "Bless LoadFile Load Dump DumpFile";
use Carp;
use Pod::Usage;
use Compat::LustreTests;
#use Compat::LTPTests;
Log::Log4perl->easy_init( { level => $DEBUG } );
my $nopts;
$nopts = 1 unless ( $ARGV[0] );

my ($testds, $groupname,  $script, $tmpl, $fw, $helpflag, $manflag, $dir );

GetOptions(
    "testds:s"     => \$testds,
    "groupname:s"  => \$groupname,
    "script:s"     => \$script,
    "tmpl:s"       => \$tmpl,
    "fw:s"         => \$fw,
    "help!"        => \$helpflag,
    "man!"         => \$manflag,
    );

pod2usage( -verbose => 1 ) if ( ($helpflag) || ($nopts) );

pod2usage( -verbose => 2 ) if ($manflag);

my $content;
if($fw eq 'ltp'){
    #$content = newLTPSuite( 'groupname'=> $groupname, 'cmdfile' => $script);
}elsif($fw eq 'lustre'){
    $content = Compat::LustreTests::newSuite(
                            name    => $groupname, 
                            script  => $script,
                            default => $tmpl);
    
}else{
    confess "Support for framework [$fw] is not implemeted"; 
}

$YAML::Stringify = 1;
my $file = "$testds/${groupname}_tests.yaml";
open REP, "> $file" or confess "Cannot create report file [$file]:" . $!;
print REP Dump($content);
close REP;

#DEBUG Dumper $content;

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



Copyright 2014 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

