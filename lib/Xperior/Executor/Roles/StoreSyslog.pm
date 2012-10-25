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
has tlog => ( is =>'rw');
has ison => ( is =>'rw', isa => 'HashRef');

requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

before 'execute' => sub{
    my $self    = shift;
    my %h;
    $self->ison(\%h);
    foreach my $n (@{$self->env->nodes}){
        my $c = $n->getExclusiveRC;
        my $tlog = '/tmp/messageslog.'.Time::HiRes::gettimeofday();

        $self->tlog($tlog);
        $self->ison->{$n->id}=$c;
        $c->create('tail',"tail -f -n 0 -v /var/log/messages > $tlog ");

        if( defined($c->exitcode) && ($c->exitcode != 0)){
            $self->addMessage('Cannot harvest log data for node '.$n->id);
            $self->ison->{$n->id}=0;
        }
    }

};


after   'execute' => sub{
    my $self    = shift;

    foreach my $n (@{$self->env->nodes}){
        if($self->ison->{$n->id}!=0){
            my $c = $self->ison->{$n->id};
            $c->kill(1);
            my $res = $c->getFile( $self->tlog,
            $self->getNormalizedLogName('messages.'.$n->id));
            if ($res == 0){
                $self->registerLogFile('messages.'.$n->id,
                     $self->getNormalizedLogName('messages.'.$n->id));
            }else{
                $self->addMessage(
                    'Cannot copy log file ['.$self->tlog."]: $res");

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


