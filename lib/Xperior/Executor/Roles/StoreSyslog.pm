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
has tlog      => ( is =>'rw');
has ison      => ( is =>'rw', isa => 'HashRef');
has storedir  => ( is =>'rw', default => '/var/log/xperior/syslog');
has remotelog => ( is =>'rw', default => '/var/log/messages');
has logname   => ( is => 'rw', default => 'messages');
requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

before 'execute' => sub{
    my $self    = shift;
    $self->ison({});
    foreach my $node (@{$self->env->nodes}) {
        my $tlog = $self->storedir . '/messages.' . Time::HiRes::gettimeofday();
        $self->tlog($tlog);
        my $c = $node->getExclusiveRC;
        $c->create('mkdir', "mkdir -p " . $self->storedir);
        $c->create('tail', "tail -f -n 0 -v $self->{remotelog} > $tlog ");

        if($c->syncexitcode) {
            $self->addMessage('Cannot harvest log data for node ' . $node->id);
        }
        else {
            $self->ison->{$node->id} = $c;
        }
    }

};


after   'execute' => sub{
    my $self    = shift;

    foreach my $n (@{$self->env->nodes}) {
        my $id = $n->id;
        my $logfile = $self->getNormalizedLogName("$self->{logname}.$id");
        if($self->ison->{$id}){
            my $c = $self->ison->{$id};
            $c->kill(1);
            my $res = $c->getFile( $self->tlog,$logfile);
            if ($res == 0){
                $self->registerLogFile($logfile,$logfile);
                $self->processSystemLog($c,$logfile);
            }else{
                $self->addMessage(
                    "Cannot copy log file [".$self->tlog."]: $res");
            }
        }
    }
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


