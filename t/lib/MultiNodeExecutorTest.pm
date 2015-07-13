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
# Please  visit http://www.xyratex.com/contact if you need additional information or
# have any questions.
#
# GPL HEADER END
#
# Copyright 2015 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#
package MultiNodeExecutorTest;
use strict; use warnings FATAL => 'all';
use Moose;
extends 'Xperior::Executor::MultiNodeSingleProcess';

our $VERSION = '0.01';


sub _prepareCommands{
    my $self    = shift;
    #$self->cmd("echo qazwsxedccrfv");
}

sub processLogs(){
    my $self    = shift;
    return $self->PASSED;
}

__PACKAGE__->meta->make_immutable;

1;