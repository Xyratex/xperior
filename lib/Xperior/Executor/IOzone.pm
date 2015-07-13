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
# Copyright 2015 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::IOzone - Module which contains IOzone specific
execution functionality

=head1 DESCRIPTION

http://www.iozone.org/
B<IOzone> wrapper module for Xperior harness. Supports IOzone load
utility execution on one or few nodes simultaneously
This module inherit L<MultiNodeSingleProcess>.

Test descriptor parameters

    iozonecmd  - full line for executing iozone

Test descriptor token for replacement
    @client_mount_point@ - mount point path, see system parameters
    @genfilename@        - random generated file name


System descriptor parameters

    client_mount_point  - path to directory which is used root for
    test execution, often it is target fs mount point

Sample test descriptor see in testds/iozone_tests.yaml


=cut

package Xperior::Executor::IOzone;
use strict;
use warnings FATAL => 'all';
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;

extends 'Xperior::Executor::MultiNodeSingleProcess';

our $VERSION = '0.01';

sub _prepareCommands{
    my $self    = shift;
    my $mp = $self->env->cfg->{'client_mount_point'};
    my $c  = $self->test->getParam('iozonecmd');
    $c =~ s/\@client_mount_point\@/$mp/g;
    $c =~ s/\@genfilename\@/"".$self->get_file_name()/ge;
    $self->cmd($c);
}

sub get_file_name{
    my $self = @_;
    my @chars = ("A".."Z", "a".."z","0".."9");
    my $f;
    $f .= $chars[rand @chars] for 1..10;
    return $f;
}

sub processLogs{
    my $self    = shift;
    return $self->PASSED;
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

Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

