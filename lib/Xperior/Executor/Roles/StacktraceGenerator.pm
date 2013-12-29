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
# Copyright 2013 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::StacktraceGenerator - Role define generatig
stacktrace into system console via /proc/sysrq-trigger usage.

=head1 DESCRIPTION

Info about sysrt : https://www.kernel.org/doc/Documentation/sysrq.txt

The role could be used in cases when test failure detected and developer needs
more infomation about current system state. When role switched on it going
over all nodes in system configuration and call 'echo t > /proc/sysrq-trigger'
and 'echo m > /proc/sysrq-trigger'.
Stacktrace will be stored in system console. The role is recommended to use
StacktraceGenerator with NetconsoleCollector or StoreConsole.


=cut

package Xperior::Executor::Roles::StacktraceGenerator;
use strict;
use warnings;
use Moose::Role;
use Data::Dumper;
use Log::Log4perl qw(:easy);

my $title = 'StacktraceGenerator';
has executeutils  => ( is => 'rw');
has sysrqtcmd        => (is => 'rw', default => 'echo t > /proc/sysrq-trigger');
has sysrqmcmd        => (is => 'rw', default => 'echo m > /proc/sysrq-trigger');
has lctldkcmd        => (is => 'rw', default => 'lctl dk');
has sysrqcmd_timeout => (is => 'rw', default => 60);
has dumpend_timeout  => (is => 'rw', default => 120);


after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    if (($self->yaml->{status_code}) == 1) {
        foreach my $n (@{ $self->env->nodes }) {
            my $c = $n->getExclusiveRC();
            DEBUG("Call 'lctl dk' on node [" . $n->ip() . "]");
            my $remotelogfile = "/tmp/lctl_dk.out." . time ();
            $c->createSync($self->lctldkcmd . " > $remotelogfile", 120);
            $self->_getLog($c, $remotelogfile, 'lctl_dk.' . $n->ip());
            INFO("Call 'sysrq' commands on node [" . $n->ip() . "]");
            $c->createSync($self->sysrqtcmd(), $self->sysrqcmd_timeout());
            $c->createSync($self->sysrqmcmd(), $self->sysrqcmd_timeout());
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



Copyright 2013 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut
