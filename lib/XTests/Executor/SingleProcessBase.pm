#
#===============================================================================
#
#         FILE:  SingleProcessBase.pm
#
#  DESCRIPTION:  Implement execution for single process tests (f.e. ior) 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      VERSION:  1.0
#      CREATED:  10/23/2011 06:39:29 PM
#===============================================================================

package XTests::Executor::SingleProcessBase;
use Moose;
use Data::Dumper;
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;

use XTests::SshProcess;
extends 'XTests::Executor::Base';
=item * 
Function execute on-clients test. Remote execution done via ssh.
Only one pocess execute on client which marked as master.
=cut
sub execute{
    my $self = shift; 
    my $mc = $self->_getMasterClient;

    $self->addYE('masterclient',$mc);
    DEBUG "MC:". Dumper $mc;
    $self->_prepareCommands;
    $self->_addCmdLogFiles;
    $self->addYE('cmd',$self->cmd);

    my $testp = XTests::SshProcess->new();
    $testp->init(
            $self->env->getNodeAddress($mc->{'node'}),
            $self->env->getNodeUser($mc->{'node'}));
    
    $testp->create($self->appname,$self->cmd);
    #all alredy started there

    my $starttime=time;
    my $endtime= $starttime 
        + $self->test->getParam('timeout');

    while( $endtime > time ){
        #monitoring timeout
        sleep 5;
        unless ( $testp->isAlive == 0 ) {
            INFO "Remote app is not alive, exiting";
            last;
        };

        DEBUG "Test alive, next wait cycle";
    }
    $self->addYE('endtime',time);
    $self->addYE('starttime',$starttime);
    $self->addYE('endtime_planned',$endtime);
    ### post processing and cleanup
    $testp->kill if($testp->isAlive == 0);

    if($testp->killed > 0){
        $self->addYE('killed','yes');
        $self->fail(
                'Killed by timeout after ['.
                $testp->killed.
                '] sec of execution');           
    }else{
        $self->addYE('killed','no');
        $self->pass;
    }
    $self->addYE('completed','yes');
    ### get logs

    $testp->getFile( $self->remote_err,
            $self->getNormalizedLogName('stderr'));
    $self->registerLogFile('stderr',
            $self->getNormalizedLogName('stderr'));

    $testp->getFile( $self->remote_out,
            $self->getNormalizedLogName('stdout'));
    $self->registerLogFile('stdout',
            $self->getNormalizedLogName('stdout'));
    ### cleanup logs
    ### end
    $self->test->tap     ( $self->tap);
    $self->test->results ($self->yaml);
    $self->write();
    return $self->tap();
}

sub _getMasterClient{
    my $self = shift;
    foreach my $lc (@{$self->env->getClients}){
        return $lc 
            if(defined( $lc->{'master'} &&
                ( $lc->{'master'} eq 'yes')));
    }
    return undef;
}

sub _addCmdLogFiles{
    my $self = shift;
    #TODO add random part
    my $r = int rand 1000000 ;
    my $tee = " | tee ";
    
    $self->options->{'cmdout'} = 0 
        unless defined  $self->options->{'cmdout'} ;

    $tee = " 1>  " if  $self->options->{'cmdout'} == 0 ;
    $self->remote_err( "/tmp/test_stderr.$r.log"); 
    $self->remote_out( "/tmp/test_stdout.$r.log");
    $self->cmd( $self->cmd ." 2>     ".$self->remote_err.
                            $tee.$self->remote_out);
}

1;
