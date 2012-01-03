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

package XTest::Executor::SingleProcessBase;
use Moose;
use Data::Dumper;
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;

use XTest::SshProcess;
extends 'XTest::Executor::Base';
=item * 
Function execute on-clients test. Remote execution done via ssh.
Only one pocess execute on client which marked as master.
=cut
sub execute{
    my $self = shift; 
    my $mcl = $self->_getMasterClient;

    #saving env data
    $self->addYE('masterclient',$mcl);
    DEBUG "MC:". Dumper $mcl;
    $self->_prepareCommands;
    $self->_addCmdLogFiles;
    $self->addYE('cmd',$self->cmd);
    
    #$self->_saveStageInfoBeforeTest;
    
    #get remote processor
    my $mclo =  
        $self->env->getNodeById($mcl->{'node'});
    my $testp = $mclo->getRemoteConnector;
    unless( defined( $testp)) {
        INFO 'Master client is:'.Dumper $mclo;
        confess "SSH to master client is undef";
    }
    ## create temprory dir
    my $td = '';
    $td = $self->env->cfg->{'tempdir'}
                if defined $self->env->cfg->{'tempdir'} ;
    $testp->createSync
        ('mkdir -p '.$self->env->cfg->{'client_mount_point'}.$td);
    #TODO add exit value check there. Now it doesn't have value.

#TODO check these values on empty or undefined values.
#$self->env->cfg->{'client_mount_point'}
#$self->env->cfg->{'tempdir'})    
   

    my $cr = $testp->create($self->appname,$self->cmd);
    if($cr == 0){
        $self->fail('Cannot start remote test process on master client');

    }
    #all alredy started there

    my $starttime=time;
    my $endtime= $starttime 
        + $self->test->getParam('timeout');

    while( $endtime > time ){
        #monitoring timeout
        sleep 1;
        unless ( $testp->isAlive == 0 ) {
            INFO "Remote app is not alive, exiting";
            last;
        };

        DEBUG "Test alive, next wait cycle";
    }
    $testp->createSync('sync',30);
    $self->addYE('endtime',time);
    $self->addYE('starttime',$starttime);
    $self->addYE('endtime_planned',$endtime);
    ### post processing and cleanup
    my $killed=0;
    my $kt=0;
    if($testp->isAlive == 0){
        my $ts = $mclo->getExclusiveRC;
        DEBUG $ts->createSync('ps afx');
        DEBUG "Owned pid is:".$testp->pid;
         $testp->kill;
         $killed=1;
         $kt=$testp->killed;
    }


    $self->addYE('completed','yes');
    
    #$self->_saveStageInfoAfterTest;

    #cleanup tempdir after execution
    $testp->createSync
        ('rm -rf '.$self->env->cfg->{'client_mount_point'}
            .$td."/*");

    ### get logs

    my $res = $testp->getFile( $self->remote_err,
            $self->getNormalizedLogName('stderr'));
    if($res == 0){
        $self->registerLogFile('stderr',
            $self->getNormalizedLogName('stderr'));
    }else{
        $self->addMessage(
            'Cannot copy log file ['.$self->remote_err."]: $res");        
    }

    $res = $testp->getFile( $self->remote_out,
            $self->getNormalizedLogName('stdout'));
    my $pr = -1;
    if($res == 0){
        $self->registerLogFile('stdout',
            $self->getNormalizedLogName('stdout'));
        $pr = $self->processLogs
            ($self->getNormalizedLogName('stdout'));
    }else{
        $self->addMessage(
            'Cannot copy log file ['.$self->remote_out."]: $res");
    }
    #calculate results status
    if($killed > 0){
        $self->addYE('killed','yes');
        $self->fail(
                'Killed by timeout after ['.
                ($kt-$starttime).
                '] sec of execution');           
    }else{
        $self->addYE('killed','no');
        if( ($testp->exitcode == 0) && ($pr == 0) ){
            $self->pass;
        }else{
            
            $self->fail($self->getReason);
        }
    }

    ### cleanup logs
    ### end
    #no idea what is good result there, so no return
    #$self->test->tap     ( $self->tap);
    $self->test->results ($self->yaml);
    #$self->write();
    #return $self->tap();
}

sub _getMasterClient{
    my $self = shift;
    foreach my $lc (@{$self->env->getClients}){
        DEBUG "Check client ". Dumper $lc;
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

__PACKAGE__->meta->make_immutable;
