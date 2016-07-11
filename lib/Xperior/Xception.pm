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

Xperior::Xception - Xperior exceptions

=head1 DESCRIPTION

Xperior exceptions which should be used for improving error processing

=cut

package Xperior::Xception;

use overload ( '""' => 'stringify' );
#use Carp qw(cluck);
use base qw(Error);

sub new {
    my $self = shift;
    my $text = "" . shift;
    my @args = ();

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;                   # Enables storing of stacktrace

    $self->SUPER::new( -text => $text, @args );

    #cluck "Exception generated";
}

1;

package TestFailed;
use base qw(Xperior::Xception);
1;

package TestError;
use base qw(Xperior::Xception);
1;

package NoSchemaException;
use base qw(Xperior::Xception);
1;

package CannotPassSchemaException;
use base qw(Xperior::Xception);
1;

package KVMException;
use base qw(Xperior::Xception);
1;

package NullObjectException;
use base qw(Xperior::Xception);
1;

package CannotConnectException;
use base qw(Xperior::Xception);
1;

package RemoteCallException;
use base qw(Xperior::Xception);
1;

package MethodNotImplementedException;
use base qw(Xperior::Xception);
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

