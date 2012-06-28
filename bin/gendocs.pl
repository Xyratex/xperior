#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  gendocs.pl
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex 
#      CREATED:  10/29/2011 11:45:44 PM
#===============================================================================

use strict;
use warnings;
use Pod::ProjectDocs;

mkdir 'html';
`autodia.pl -d lib/Xperior -r  -o html/classes.png -z -D -H -K`;

my $pd = Pod::ProjectDocs->new(
    outroot => 'html/',
    libroot =>  ['bin', 'lib', 'doc'],
    title   => 'Xperior',
    forcegen => 1,
    desc   => 'Xperior harness'
);
$pd->gen();


#or use pod2projdocs on your shell
#pod2projdocs -out /output/directory -lib /your/project/lib/root


