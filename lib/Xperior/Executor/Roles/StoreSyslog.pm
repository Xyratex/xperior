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

Xperior::Executor::Roles::StoreSyslog - Role define harvesting info from
master client host

=cut

package Xperior::Executor::Roles::StoreSyslog ;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
has tlog      => ( is =>'rw', isa => 'HashRef');
has ison      => ( is =>'rw', isa => 'HashRef');
has storedir  => ( is =>'rw', default => '/var/log/xperior/syslog');
has remotelog => ( is =>'rw', default => '/var/log/messages');
has logname   => ( is => 'rw', default => 'messages');
requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';
my $title = 'StoreSyslog';

before 'execute' => sub{
    my $self    = shift;
    $self->beforeBeforeExecute($title);
    $self->ison({});
    $self->tlog({});
    foreach my $node (@{$self->env->nodes}) {
        my $tlog = $self->storedir . '/messages.' . Time::HiRes::gettimeofday();
        $self->tlog->{$node->id} = $tlog;
        my $c = $node->getExclusiveRC;
        $c->createSync("mkdir -p " . $self->storedir);
        $c->create('tail', "tail -f -n 0 -v $self->{remotelog} > $tlog ");

        if($c->exitcode) {
            $self->addMessage('Cannot harvest log data for node ' . $node->id);
        }
        else {
            $self->ison->{$node->id} = $c;
        }
    }
    $self->afterBeforeExecute($title);
};


after   'execute' => sub{
    my $self    = shift;
    $self->beforeAfterExecute($title);
    foreach my $n (@{$self->env->nodes}) {
        my $id = $n->id;
        my $logfile = $self->getNormalizedLogName("$self->{logname}.$id");
        my $tlog = $self->tlog->{$id};
        if($self->ison->{$id}){
            my $c = $self->ison->{$id};
            $c->kill(1);
            my $res = $c->getFile($tlog, $logfile);
            $c->createSync("rm -f $tlog");
            if ($res == 0){
                $self->registerLogFile($logfile,$logfile);
                $self->processSystemLog($c,$logfile);
            }else{
                $self->addMessage(
                    "Cannot copy log file [".$tlog."]: $res");
            }
        }
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut


