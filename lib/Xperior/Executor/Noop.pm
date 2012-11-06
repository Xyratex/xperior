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

Xperior::Executor::Noop - basic executor

=cut

package Xperior::Executor::Noop;
use Moose;
extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = '0.01';


sub execute{
    my $self = shift;
    my $id = $self->test->getParam('id');
    $self->fail;
    $self->addYE('starttime',time);
    $self->addYE('testid',$id);
    $self->addYE('message','Noop engine, empty test');
    $self->addYE('killed','no');
my $ml = <<ML
Qwerty
Asdfg
Zxcvb
ML
;
    $self->addYE('multiline1',$ml);
    $self->addYE('multiline2',"qwerty\n"."asdfgh\n\nzxcvbn");
    $self->addYE('completed','yes');
    $self->addYE('endtime_planned',time);
    $self->addYE('endtime',time);

    $self->pass;
    $self->test->results ($self->yaml);
}

__PACKAGE__->meta->make_immutable;

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

