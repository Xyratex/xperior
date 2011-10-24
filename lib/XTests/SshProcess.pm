#
#===============================================================================
#
#         FILE:  SshProcess.pm
#
#  DESCRIPTION: Module which implement remote process control for singlie process over ssh
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      VERSION:  1.0
#      CREATED:  10/08/2011
#===============================================================================
package XTests::SshProcess;
use Moose;
use Data::Dumper;
use Cwd qw(chdir);
use File::chdir;
use File::Path;
use Log::Log4perl qw(:easy);
use Carp;
use XTests::Utils;

has port      => (is=>'rw');
has host      => (is=>'rw');
has user      => (is=>'rw');
has pass      => (is=>'rw');

has pidfile   => (is=>'rw');
has pid       => (is=>'rw');
has appcmd    => (is=>'rw');
has appname   => (is=>'rw');

has killed    => (is=>'rw');

has hostname  => (is=>'rw');
has osversion => (is=>'rw');


#ssh -f ryg@localhost "nohup sleep 15 &"
#TODO add test on it
sub _sshSyncExec{
    my ($self, $cmd, $timeout) = @_;
    DEBUG "XTest::SshProcess->_sshSyncExec";
    my $cc =  "ssh -f ". $self->user ."@". $self->host . 
            " \"$cmd\" & ";
    DEBUG "Remote cmd is [$cc]";
    return `$cc`;
}
#TODO add test on it
sub _sshAsyncExec{
    my ($self, $cmd, $timeout) = @_;
    DEBUG "XTest::SshProcess->_sshAsyncExec";
    my $cc =  "ssh -f ". $self->user ."@". $self->host . 
            " \"$cmd\" & ";
    DEBUG "Remote cmd is [$cc]";
    return system($cc);
}



sub init {
    DEBUG "Automator::SshUnixProcess->init";
    my $self = shift;
    $self->pidfile('/tmp/pid_ssh_xxx');
    $self->host(shift);
    $self->user(shift);
    $self->port(shift);
    $self->killed(0);   
    
    my $ver = trim $self->_sshSyncExec("uname -a" ,1)
      or confess "unable to check remote system: " . $_;
    
    my $h = trim  $self->_sshSyncExec("hostname",1 );
    INFO "Executing on host [$h]";
    $self->hostname($h);
    INFO "Remote system is <$ver>";
    $self->osversion($ver);
}


sub _findPid{
    my $self   = shift;
    my $mode   = shift;
    $self->pid(-1);     
    my $out = $self->_sshSyncExec ("cat ".$self->pidfile , 1);

    foreach my $s (split(/\n/,$out)){
        DEBUG "Check line for PID [$s]\n";
        if($s =~ m/pid\:\[(\d+)\]/){
            $self->pid($1);
            DEBUG "PID found: [".$self->pid."]\n"; 
            return 1;
        }
    }    
    return -1;
}    

sub create {
    my ($self,$name,$app) = @_;
    $self->appname($name);
    $self->appcmd($app);
    DEBUG "[$name]: XTest::SshProcess create";
    DEBUG "[$name]: Work dir is $CWD";
    DEBUG "[$name]: App to run [$app] on host[". $self->host . "]";

    DEBUG "Start remote ssh process[ $app ]";
   

    my $rd = $self->_sshSyncExec("rm ".$self->pidfile );
    DEBUG "Del remote pid file: $rd";
    my $pf = $self->pidfile;

my $ss = <<"SS";
$app &  
pid=\\\$!  
echo pid:[\\\$pid] > $pf 

SS
    #FIXME add temp part to name 
    #      and clean code after execution
    my $tef = '/tmp/remote_exec'; 
    my $fco = $self->_sshSyncExec("echo  '$ss' > $tef");
    DEBUG "Starting ............";    
    my $s  =  $self->_sshAsyncExec("sh $tef");    
    DEBUG "Remote app started:$s";
    sleep 5; 
    $self->_findPid();
    
    if($self->pid == -1){
        confess "Remote process doesn't start or found in pid file";
    }        
    
    DEBUG "App [$app] started on ".$self->host."\n";
    DEBUG "[$name]: Run aplication [$app] ";
    return $self->pid;
}

sub kill {
    DEBUG "XTest::SshProcess->kill";
    my $self = shift;
    my $pid  = $self->pid;
    my $name = $self->appname;
    DEBUG "[$name]: Killing job [" . $name . "] \n";
    $self->_sshSyncExec("kill -15 $pid");
    sleep 10;
    $self->_sshSyncExec("kill -9  $pid");
    $self->killed(time);
    DEBUG "[$name:$pid]*** Killed!";
}

sub isAlive {
    DEBUG "XTest::SshProcess->isAlive";
    my $self = shift;
    my $pid  = $self->pid;
    my $name = $self->appname;

    my $output = $self->_sshSyncExec("ps ax ww | grep $pid | grep -v ps | grep -v grep" );
    unless ( defined($output) ) {
        ERROR "unable to check remote system: [$output]";
        return -1;
    }

    DEBUG "[output] = $output";
    if ( trim($output) eq "" ) {
        INFO "Remote process [$name] is not found, ps output is empty";
        return -1;
    }
    INFO "Remote process is alive! ";
    return 0;
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

sub getFile {
    my ($self, $rfile, $lfile)  = @_;

    DEBUG "Getting ". $self->user.'@'.$self->hostname.
    ':'. $rfile.' to '.$lfile;

    return runEx("scp -rp ".$self->user.'@'.
            $self->hostname.":$rfile $lfile");
}

1;
=item
sub killAll {
    INFO "SshUnixProcess->killAll";
    my $self = shift;
    my $proc = shift;
    my $ssh  = $self->{ssh};
    my $pid  = $self->{pid};

    #FIXME hudson is incorrect! just for short time!
    my $output = $ssh->capture( { timeout => 10 },
        "ps w | grep $pid | grep -v ps | grep -v grep" );    
##        "ps w | grep hudson | grep -v ps | grep -v grep" );

    #TODO
    #temprorary disable it
    #if ( defined($output) && $output ne "" ) {
    #    INFO "unable list processes on remote system: " . $ssh->error;
    #    return;
    #}
    WARN "Remote [$proc] processes:\n" . $output if defined $output;
    WARN "No remote processes" if !( defined $output );

   #my $cmd= "kill -9 \`ps w | grep $proc | grep -v grep | awk '{print \$1}'\`";
    my $cmd = "killall -9 $proc";
    my $output1 = $ssh->capture( { timeout => 10 }, $cmd );
}
=cat
