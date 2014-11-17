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

Xperior::Executor::Roles::LustreClientStatus - Role define harvesting info 
from master client host

=cut

package Xperior::Executor::Roles::LustreClientStatus;

use Moose::Role;

requires 'env';

before 'execute' => sub{
    my $self    = shift;
    $self->_saveStageInfo('before');

};


after   'execute' => sub{
    my $self    = shift;
    $self->_saveStageInfo('after');
};


sub _saveStageInfo{
    my ($self,$item) = @_;
    my %info;
    my $mc = $self->env->getNodeById
        ($self->_getMasterNode->{'node'});
    $info{'lfs_freespace'}  = $mc->getLFFreeSpace;
    $info{'lfs_freeinodes'} = $mc->getLFFreeInodes;
    $info{'lfs_capacity'}   = $mc->getLFCapacity;
    $self->addYE($item."_execution",\%info);
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


