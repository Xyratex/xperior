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
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

gendocs.pl

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use File::Path;
use Pod::Simple::HTMLBatch;
use Pod::Simple::XHTML;


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
$batchconv->add_css('http://www.perl.org/css/perl.css');
$batchconv->css_flurry(0);
$batchconv->javascript_flurry(0);

my @in = ('bin','doc','lib');
$batchconv->batch_convert( \@in, 'html' );

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


