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
# Please  visit http://www.seagate.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2015 Seagate Technology LLC
#
# Author: Alexander Lezhoev<Alexander.Lezhoev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::VmcoreGenerator - Role define generatig
vmcore via /proc/sysrq-trigger usage.

=head1 DESCRIPTION

Info about sysrt : https://www.kernel.org/doc/Documentation/sysrq.txt

The role could be used in cases when test failure detected and developer needs
more infomation about current system state. When role switched on it going
over all nodes in system configuration and call 'echo c > /proc/sysrq-trigger'.


=cut

package Xperior::Executor::Roles::VmcoreGenerator;
use strict;
use warnings;
use Moose::Role;
use Data::Dumper;
use Log::Log4perl qw(:easy);

my $title = 'VmcoreGenerator';
has executeutils  => ( is => 'rw');
has sysrqccmd        => (is => 'rw', default => "echo c > /proc/sysrq-trigger");
has sysrqcmd_timeout => (is => 'rw', default => 60);
has dumpend_timeout  => (is => 'rw', default => 120);


after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    if (($self->yaml->{status_code}) == 1) {
        $self->addYE('VmcoreGenerator_cmd', $self->sysrqccmd());
        $self->addYE('VmcoreGenerator_time', time);
        $self->addMessage('VmcoreGenerator:VmCore generation initiated');
        foreach my $n (@{ $self->env->nodes }) {
            my $c = $n->getRemoteConnector();
            INFO("Call 'sysrq-c' command on node [" . $n->ip() . "]");
            $c->run($self->sysrqccmd(), timeout => $self->sysrqcmd_timeout());
        }

        #TODO wait end of sysrq dumping
    }
    $self->afterAfterExecute($title);
};

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



Copyright 2015 Seagate Technology LLC

=head1 AUTHOR

Alexander Lezhoev<Alexander.Lezhoev@seagate.com>

=cut
