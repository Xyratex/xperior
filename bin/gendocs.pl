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
use File::Path;
use Pod::Simple::HTMLBatch;

rmtree('html');
mkdir 'html';

print `autodia.pl -d lib/Xperior -r  -o html/classes.png -z -D -H -K`;

my $header = <<HEADER
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>Xperior</title>
</head>
<body>
<div class="box">
  <h1 class="t1">Xperior</h1>
  <table>
    <tr>
      <td class="label">Description</td>
      <td class="cell">Xperior harness</td>
    </tr>
  </table>
</div>


HEADER
;

my $batchconv = Pod::Simple::HTMLBatch->new;
$batchconv->verbose(3);
$batchconv->contents_page_start($header);
$batchconv->add_css( '../podstyle.css' );

my @in = ('bin','doc','lib');
$batchconv->batch_convert( \@in, 'html' );


