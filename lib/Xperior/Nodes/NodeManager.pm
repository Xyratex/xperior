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

Xperior::Nodes::NodeManager - Base class for different nodes support.

=head1 DESCRIPTION

Abstract class implements simple functionality for check node start and provide
method list which must be implemented in inheritors.

=head2 METHODS

=cut

package Xperior::Nodes::NodeManager;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Net::Ping;

use Moose::Role;

has 'nodedescriptor' => ( is => 'rw', isa => 'Str');
has 'console'        => ( is => 'rw');


=head3  halt

Shutdown and/or power off remote host. Asynchronous operation.

=head3 start

Boot and/or power on remote host. Asynchronous operation.

=head3 isAlive

Check that system is alive by control system. Doesn't mean that node is available by network.

=head3 sync

Wait some time to be sure that action (start, halt) is processed by control system.

=head3 restoreSystem

restore OS state to orignal state and reboot

=cut

requires qw(halt start restoreSystem isAlive sync);

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


