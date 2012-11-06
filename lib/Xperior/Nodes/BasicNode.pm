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

Xperior::Nodes::BasicNode - simpliest nodemanager

=head1 DESCRIPTION

The simpliest nodemanager which doesn't support any feature. Abstract class.

=cut

package Xperior::Nodes::BasicNode;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Carp;
use Error qw(try finally except otherwise);
use Xperior::SshProcess;
use Xperior::Utils;
use Xperior::Xception;
use Moose::Role;
with qw( Xperior::Nodes::NodeManager );

sub sync{
    throw MethodNotImplementedException("sync is not implemented because it is basic implementation");
}

sub isAlive {
    throw MethodNotImplementedException "isAlive is not implemented because it is basic implementation";
}


sub halt {
    throw MethodNotImplementedException "halt is not implemented because it is basic implementation";
}

sub start {
    throw MethodNotImplementedException "start is not implemented because it is basic implementation";
}

sub restoreSystem {
    throw MethodNotImplementedException "restoreSystem is not implemented because it is basic implementation";
}
1;

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


