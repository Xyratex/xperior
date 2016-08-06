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

Xperior::Executor::Roles::StoreConsole - Role defines harvesting info
from files which contains console fileson host where Xperior isexecuted.
Main usage scenario with console files from virtual machines.

See also Xperior::Executor::Roles::NetconsoleCollector

=cut

package Xperior::Executor::Roles::StoreConsole;

use strict;
use warnings;
use Moose::Role;
use Time::HiRes;
use Proc::Simple;
use Xperior::Utils;
use Log::Log4perl qw(:easy);


our $VERSION = "0.0.2";

my $title = 'StoreConsole';
has console_procs => ( is =>'rw', isa => 'HashRef');
requires    'env', 'addMessage', 'getNormalizedLogName';

before 'execute' => sub{
    my $self = shift;
    $self->beforeBeforeExecute($title);
    my %h;
    $self->console_procs(\%h);
    foreach my $n (@{$self->env->nodes}){
        $self->console_procs->{$n->id}=undef;
        unless( defined($n->console)){
            $self->addMessage(
                    "No console defined for node [".$n->id."]");
            next;
        }
        my $console = $n->console;
        my $log  = $self->getNormalizedLogName('console.'.$n->id);

        my $proc = Proc::Simple->new();
        $proc->kill_on_destroy(1);
        $proc->signal_on_destroy("KILL");
        DEBUG "Start kvm console saving from file $console";
        $proc->start("sudo tail -f -n 0 -v $console 2>&1 > $log");
        sleep 1;
        if($proc->poll){
            DEBUG "Started tail, pid:".$proc->pid();
            $self->console_procs->{$n->id}=$proc;
            $self->registerLogFile('console.'.$n->id,
                     $self->getNormalizedLogName('console.'.$n->id));

        }else{
            $self->addMessage(
                    "Cannot read console file on node [".$n->id."]");
        }
    }
    $self->afterBeforeExecute($title);
};


after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    foreach my $n (@{$self->env->nodes}){
        DEBUG "Check node ".$n->id;
        if(defined($self->console_procs->{$n->id})){
            my $proc = $self->console_procs->{$n->id};
            DEBUG "tail ".$n->id." proc pid for killing:".$proc->pid();
            #assumption - proc group has same pid as first
            # app, e.g. in our case it is sh
            #action - list process for pgroup based in sh pid,
            #kill it
            kill_tree($proc->pid());
            $proc = undef;
            $self->console_procs->{$n->id} = undef;
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


