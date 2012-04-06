#
#===============================================================================
#
#         FILE:  Xperior/Executor/Roles/StoreSyslog.pm 
#
#  DESCRIPTION:  Role define harvesting info from master client host 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  12/21/2011 11:45:19 AM
#===============================================================================

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
