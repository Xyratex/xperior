#
#===============================================================================
#
#         FILE:  XTest/Executor/Roles/StoreConsole.pm 
#
#  DESCRIPTION:  Role define harvesting info from master client host 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  12/21/2011 11:45:19 AM
#===============================================================================

package XTest::Executor::Roles::StoreConsole;

use Moose::Role;
use Time::HiRes;
use Proc::Simple;
use XTest::Utils;

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
        $proc->start("sudo tail -f -n 0 -v $console 2>&1 > $log");
        sleep 1;
        if($proc->poll){
            $self->procs->{$n->id}=$proc;
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
