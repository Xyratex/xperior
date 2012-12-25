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

Xperior::Executor::Roles::StoreConsole - Role define harvesting info from master client host

=cut

package Xperior::Executor::Roles::StoreConsole;

use Moose::Role;
use Time::HiRes;
use Proc::Simple;
use Xperior::Utils;
use Log::Log4perl qw(:easy);


has procs => ( is =>'rw', isa => 'HashRef');

requires    'env', 'addMessage', 'getNormalizedLogName';

before 'execute' => sub{
    my $self    = shift;
    my %h;
    $self->procs(\%h);
    foreach my $n (@{$self->env->nodes}){
        $self->procs->{$n->id}=undef;
        unless( defined($n->console)){
            $self->addMessage(
                    "No console defined for node [".$n->id."]");
            next;
        }
        my $console = $n->console;
        my $log  = $self->getNormalizedLogName('console.'.$n->id);

        my $proc = Proc::Simple->new();
        DEBUG "Start kvm console saving from file $console";
        $proc->start("sudo tail -f -n 0 -v $console 2>&1 > $log");
        sleep 1;
        if($proc->poll){
            $self->procs->{$n->id}=$proc;
            $self->registerLogFile('console.'.$n->id,
                     $self->getNormalizedLogName('console.'.$n->id));

        }else{
            $self->addMessage(
                    "Cannot read console file on node [".$n->id."]");
        }
    }

};


after   'execute' => sub{
    my $self    = shift;

    foreach my $n (@{$self->env->nodes}){
        if(defined($self->procs->{$n->id})){
            my $proc = $self->procs->{$n->id};
            #$proc->kill;
            runEx("sudo kill -TERM -".$proc->pid);

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


