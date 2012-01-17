#
#===============================================================================
#
#         FILE:  SshProcess.pm
#
#  DESCRIPTION: Module which implements remote process control for singlie process over ssh
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  10/08/2011
#===============================================================================

=pod

=head1 NAME

XTest::SshProcess - implements remote process control for single process over ssh

=head1  DESCRIPTION

The module is specially designed to be easily replaced by other module 
which provide same interface, possible via other protocol.

Modules support two serial workflows, opposed to a parallel, that a user is resposible to control.

=over 2

=item Workflow 1

User creates long-time process on remote nodes, the process is executed in background on a target node 
and deattached from console.
The stderr/stdout capturing and download is a user responsibility, that can be done, for example,
by standard output rediction via command line.

Functions to be used: B<create>, B<kill>, B<isAlive> and fields B<exitcode> and B<pid>.

=item Workflow 2

Create short-time process on remote nodes with capturing stderr/stdout. It behaves as perl B<``> (backtics) command.

Function to be used: B<createSync> and field B<exitcode>

=back

=head2 Functions

=over 2

=cut

package XTest::SshProcess;
use Moose;
use Data::Dumper;
use Cwd qw(chdir);
use File::chdir;
use File::Path;
use Log::Log4perl qw(:easy);
use Carp;
use Proc::Simple;
use XTest::Utils;
use Time::HiRes;

with qw(MooseX::Clone);

has port => ( is => 'rw' );
has host => ( is => 'rw' );
has user => ( is => 'rw' );
has pass => ( is => 'rw' );

has pidfile      => ( is => 'rw' );
has ecodefile    => ( is => 'rw' );
has rscrfile     => ( is => 'rw' );
has pid          => ( is => 'rw' );
has appcmd       => ( is => 'rw' );
has appname      => ( is => 'rw' );
has exitcode     => ( is => 'rw' );
has syncexitcode => ( is => 'rw' );
has bprocess     => ( is => 'rw' );

has killed => ( is => 'rw' );

has hostname  => ( is => 'rw' );
has osversion => ( is => 'rw' );

#TODO speed improvement via socket sharing

#hint:
#ssh exits with the exit status of the remote command which can be find with echo $? command.
#Or value 255 is return, if an error occurred while processing request via ssh session
#65280 - FF for script case return

#do pool check status to prevent false deatch report
sub _sshSyncExec {
    my ( $self, $cmd, $timeout ) = @_;
    my $step = 0;
    my $AT   = 5;
    my $r    = undef;
    while  ( $step < $AT  ) {
        sleep $step;
        $self->syncexitcode(undef);
        $r = $self->_sshSyncExecS( $cmd, $timeout );
        return $r if ((defined($self->syncexitcode ))
                    and ($self->syncexitcode != -100) #timeout
                    and ($self->syncexitcode != 65280) #connect
                );
        $step++;
        my $ec = $self->syncexitcode;
        $ec = 'undef' unless( defined( $self->syncexitcode));
        DEBUG "Sync attemp [$step], exit code is :[$ec], retry...";
    }
    return $r;
}

sub _sshSyncExecS {
    my ( $self, $cmd, $timeout ) = @_;
    $timeout = 30 unless defined $timeout;
    DEBUG "XTest::SshProcess->_sshSyncExec";
    my $cc =
        "ssh -o  'BatchMode yes' "
      . "-o 'AddressFamily inet' "
      . "-o 'ConnectTimeout=10' "

      #."-o 'StrictHostKeyChecking=no' "
      #            ."-o 'UserKnownHostsFile=/dev/null' "
      . "-o 'ServerAliveInterval=600' "
      . "-o 'ServerAliveCountMax=15' " . " -f "
      . $self->user . "@"
      . $self->host
      . " \"$cmd\" 2>&1 ";
    DEBUG "Remote cmd is [$cc], timeout is [$timeout]";

    my $out = '';
    eval {
        local $SIG{ALRM} = sub {
            $self->syncexitcode(-100);
            $self->killed(time);
            #print "*******************Killed by timeout !\n";
            die "alarm clock restart";
        };
        alarm $timeout;
        #do main action
        $out = `$cc`;
        alarm 0;    # cancel the alarm asap
    };
    alarm 0;        # race condition protection

    #DEBUG "****[$out]***";
    #DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    #die if $@ && $@ !~ /alarm clock restart/; # reraise
    if ( $@ =~ m/alarm\s+clock\s+restart/ ) {
        $self->syncexitcode(-100);
        $self->killed(time);
        WARN "SSH sync execution killed by timeout !\n";
        return undef;
    }
     $self->syncexitcode( ${^CHILD_ERROR_NATIVE} );
    if ( ${^CHILD_ERROR_NATIVE} == 0xFF00 ) {
        WARN "SSH exit code mean connection problem  [" . ${^CHILD_ERROR_NATIVE} . "](sync mode)";
        return undef;
    }
    #DEBUG "--------------";
    return $out;
}

sub _sshAsyncExec {
    my ( $self, $cmd, $timeout ) = @_;
    DEBUG "XTest::SshProcess->_sshAsyncExec";
    my $sc    = 1;
    my $alive = 0;
    my $cc =
        "ssh  -o  'BatchMode yes' "
      . "-o 'AddressFamily inet' "
      . "-o 'ConnectTimeout=10' " . "-f "
      . $self->user . "@"
      . $self->host
      . " \"$cmd\"  ";
    DEBUG "Remote cmd is [$cc]";
    my $step = 0;
    my $AT = 5;
    #this cycle is workaround for connection problem,
    #which observed too rare.
    while ( ( $sc != 0 ) and ( $step < $AT ) ) {
        $self->bprocess( Proc::Simple->new() );
        $self->bprocess->start($cc);
        $self->bprocess->kill_on_destroy(1);
        DEBUG `/bin/sleep 5`;    #hack, looks like perl's sleep
                                 #doesn't work there
        $sc = $self->bprocess->exit_status();

        #$alive = $self->bprocess->poll;
        DEBUG "[$step] local async result = [$sc]";

        #DEBUG "[$step] local alive  = [$alive]";
        $step++;
    }
    return $sc;
}

=item init ($host, $user, $port)

Initialize module. Protocol is only ssh.

=cut

sub initTemp {
    my $self = shift;
    $self->pidfile( '/tmp/xtest_pid_ssh_' . Time::HiRes::gettimeofday() );
    $self->ecodefile( '/tmp/remote_exit_code_' . Time::HiRes::gettimeofday() );
    $self->rscrfile(
        '/tmp/remote_script_' . Time::HiRes::gettimeofday() . '.sh' );

}

sub init {
    DEBUG "Automator::SshUnixProcess->init";
    my $self = shift;
    $self->initTemp;
    $self->host(shift);
    $self->user(shift);
    $self->port(shift);
    $self->killed(0);
    $self->exitcode(0);

    my $nocrash = shift;

    my $ver = 'none';
    $ver = trim $self->_sshSyncExec( "uname -a", 30 );

    #DEBUG "-------------------------------";
    #DEBUG ${^CHILD_ERROR_NATIVE};
    #DEBUG $self->exitcode;
    #DEBUG $self->killed;
    if (   ( ${^CHILD_ERROR_NATIVE} != 0 )
        || ( $self->exitcode != 0 )
        || ( $self->killed != 0 ) )
    {
        WARN "SshProcess cannot be initialized";
        if ( defined($nocrash) && $nocrash ) {
            return -99;
        }
        else {
            confess "\nSSH returns non-zero values on previous command:"
              . ${^CHILD_ERROR_NATIVE};
        }
    }

    my $h = trim $self->_sshSyncExec( "hostname", 15 );
    INFO "Executing on host [$h]";
    $self->hostname($h);
    DEBUG "Remote system is <$ver>";
    $self->osversion($ver);
    return 0;
}

#TODO test on it
sub _findPid {
    my $self = shift;
    $self->pid(-1);
    my $out = $self->_sshSyncExec( "cat " . $self->pidfile, 30 );

    return -1 unless defined $out;

    foreach my $s ( split( /\n/, $out ) ) {
        DEBUG "Check line for PID [$s]\n";
        if ( $s =~ m/pid\:\[(\d+)\]/ ) {
            $self->pid($1);
            DEBUG "PID found: [" . $self->pid . "]\n";
            return 1;
        }
    }
    return -1;
}

=item createSync ($command, $timeout)

Execute remote process and catch stderr/std and exit code. Function exit when remote execution done.

Function have one parameter - command for start on emote node.

=cut

sub createSync {
    my ( $self, $app, $timeout ) = @_;
    $self->appcmd($app);
    DEBUG "XTest::SshProcess createSync";
    DEBUG "App to run [$app] on host[" . $self->host . "]";
    my $ecf = $self->ecodefile;
    $self->killed(0);
    $self->exitcode(undef);
    my $ss = <<"SS";
$app   
echo \\\$? > $ecf 
SS

    my $tef = $self->rscrfile;
    my $fco = $self->_sshSyncExec("echo  '$ss' > $tef");

    my $s = $self->_sshSyncExec( "sh $tef", $timeout );
    DEBUG "Remote app completed";

    if ( $self->killed == 0 ) {
        $self->exitcode( trim $self->_sshSyncExec("cat $ecf") );
#$self->exitcode($self->syncexitcode);
    }
    return $s;

}

=item create ($name, $command)

Execute remote process with unattached stderr/stdout and exit. Pid is savednon remote fs. Exit code is saved after process end.

Parameters:

=over 2

=item $name

name of process which can be seen on remote node. Can be used in B<killall> call. Now is not used somehow. TBI.

=item $command

command line which will be executed on remote node

=back

Returns:

=over 4

=item 0

Successful start

=item -1 

Cannot find remote process

=item -2

Cannot start application

=back


=cut

sub create {
    my ( $self, $name, $app ) = @_;
    $self->appname($name);
    $self->appcmd($app);
    DEBUG "[$name]: XTest::SshProcess create";
    DEBUG "[$name]: App to run [$app] on host[" . $self->host . "]";
    $self->killed(0);

    my $pf = $self->pidfile;
    my $rd = $self->_sshSyncExec( "rm -rf " . $pf );
    DEBUG "Del remote pid file: $pf";
    my $ecf = $self->ecodefile;
    my $ss  = <<"SS";
$app &  
pid=\\\$!  
echo pid:[\\\$pid] > $pf 
wait \\\$pid
echo \\\$? > $ecf 
SS

    #TODO  clean /tmp after execution and test it
    my $tef = $self->rscrfile;
    my $fco = $self->_sshSyncExec("echo  '$ss' > $tef");
    DEBUG "Starting async ............";
    my $s = $self->_sshAsyncExec("sh $tef");
    unless ( $s == 0 ) {
        WARN "Cannot create remote process";
        return -2;
    }
    DEBUG "Remote async app started";
    sleep 3;
    $self->exitcode(undef);

    #cycle workaround for long remote part start
    # wait 6*5 sec for pid file on remote side
    $self->_findPid();

    if ( $self->pid == -1 ) {

        #confess
        WARN "Remote process doesn't start or found in pid file";
        return -1;
    }

    DEBUG "App [$app] started on " . $self->host . "\n";
    DEBUG "[$name]: Run aplication [$app] ";
    return $self->pid;
}

=item kill ($mode)

Kill process which was created by create via saved pid.

=cut

sub kill {
    my ( $self, $mode ) = @_;
    DEBUG "XTest::SshProcess->kill";
    my $pid  = $self->pid;
    my $name = $self->appname;
    $mode = 0 unless defined $mode;

    if( (!defined($pid)) or ($pid eq '') ){
        INFO "PID is empty, exiting";
        return;
    }

    DEBUG "[$name]: Killing job [" . $name . "], mode[$mode] \n";
    if ( $mode == 0 ) {
        $self->_sshSyncExec("kill -15 $pid");
        sleep 10;
    }
    $self->_sshSyncExec("kill -9  $pid");
    $self->killed(time);
    $self->bprocess->kill;
    DEBUG "[$name:$pid]*** Killed!";
    $self->exitcode(-99);
}

=item isAlive

Check process status on remote system via saved pid. Also this function get exit code from remote side if application is exited or killed.

=cut

#sub isAlive {
#    DEBUG "XTest::SshProcess->isAlive";
#    my $self = shift;
#    my $pid  = $self->pid;
#    my $name = $self->appname;
#    my $o    = trim $self->_sshSyncExec(" kill -0 $pid 2>&1; echo \$? ");
#    unless ( defined($o) ) {
#        ERROR "unable to check remote system: [$o]";
#        return -99;
#    }
#
#    if ( $o =~ m/^0$/ ) {
#        DEBUG "Remote process is alive! ";
#        return 0;
#    }
#    $self->exitcode( trim $self->_sshSyncExec( "cat " . $self->ecodefile ) );
#    DEBUG "Remote process is not found! ";
#    return -1;
#}

sub isAlive {
    DEBUG "XTest::SshProcess->isAlive";
    my $self = shift;
    my $pid  = $self->pid;
    my $name = $self->appname;
    my $o;
    my $step =1;
    my $AT = 3;
    while ($AT > $step ){
        $o= trim $self->_sshSyncExec(" ps -o pid=  -p $pid h 2>&1; echo \$? ");
      if((defined($o)) and ($o =~ m/^\s*$pid\s*/ )){
          last;
      }
      sleep 1;
      $step++;
      DEBUG "<$step> recheck process status";
    }
    #  DEBUG "*********** $o";
    unless ( defined($o) ) {
        ERROR "unable to check remote system, no output got";
        return -99;
    }

    if ( $o =~ m/^\s*$pid\s*/ ) {
        DEBUG "Remote process is alive! ";
        return 0;
    }
    $self->exitcode( trim $self->_sshSyncExec( "cat " . $self->ecodefile ) );
    DEBUG "Remote process is not found, sync exit code is: [".$self->syncexitcode."], app exit code is :[.".$self->exitcode."]";
    return -1;
}

#sub sendFile {
#    my $localdir  = shift;
#    my $user      = shift;
#    my $host      = shift;
#    my $remotedir = shift;
#
#    DEBUG "Sending $localdir to ${user} @ ${host} : $remotedir";
#
#    runExternal("scp -rp $localdir ${user}\@${host}:$remotedir");
#
#}

=item getFile ($remote_file, $local_file)

Get file from remote system. TODO add tests on it.

Return 0 if file copied and string if error occurred.

=cut

sub getFile {
    my ( $self, $rfile, $lfile ) = @_;

    DEBUG "Getting "
      . $self->user . '@'
      . $self->hostname . ':'
      . $rfile . ' to '
      . $lfile;

    return runEx(
        "scp -rp " . $self->user . '@' . $self->hostname . ":$rfile $lfile" );
}

=back

=cut

1;
