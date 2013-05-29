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

Xperior::SshProcess - The module implements remote process control for 
single process over ssh

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

Function to be used: B<createSync> and field B<syncexitcode>

=back

=cut

package Xperior::SshProcess;
use Moose;
use Data::Dumper;
use Cwd qw(chdir);
use File::chdir;
use File::Path;
use File::Temp qw(:mktemp);

use Log::Log4perl qw(:easy);
use Carp;
use Proc::Simple;
use Xperior::Utils;
use Time::HiRes;

# Do not assign anything, because it is determined in BEGIN block
my $UserKnownHostsFile;
BEGIN {
	my $f;
	($f, $UserKnownHostsFile) = mkstemp("/tmp/ssh_user_known_hosts_file_XXXX");
	close $f;
}

END {
	unlink $UserKnownHostsFile;
}

with qw(MooseX::Clone);

=head2 Fields

=head3 port 

Port which is used for ssh connection

=head3 host

Host which is used for ssh conenction

=head3 user

User which is used for ssh connection, no default

=head3 exitcode

Exit code from latest executed command via C<create> call.

=head3 syncexitcode

Exit code from latest executed command via C<createSync> call.

=head3 killed

Flag set if killed latest executed command via C<create> call.

=cut

has port => ( is => 'rw' );
has host => ( is => 'rw' );
has user => ( is => 'rw' );
has pass => ( is => 'rw' );

has pidfile       => ( is => 'rw' );
has ecodefile     => ( is => 'rw' );
has syncecodefile => ( is => 'rw' );
has rscrfile      => ( is => 'rw' );
has pid           => ( is => 'rw' );
has appcmd        => ( is => 'rw' );
has appname       => ( is => 'rw' );
has exitcode      => ( is => 'rw' );
has syncexitcode  => ( is => 'rw' );
has bprocess      => ( is => 'rw' );

has killed => ( is => 'rw' );

has hostname  => ( is => 'rw' );
has osversion => ( is => 'rw' );



=back

=head2 Functions

=cut

#TODO speed improvement via socket sharing

#hint:
#ssh exits with the exit status of the remote command which can be find with echo $? command.
#Or value 255 is return, if an error occurred while processing request via ssh session
#65280 - FF for script case return

#do pool check status to prevent false deatch report
sub _sshSyncExec {
    my ( $self, $cmd, $timeout ) = @_;
    $timeout = 30 unless defined $timeout;
    my $step = 0;
    my $AT   = 5;
    my $r    = undef;
    while ( $step < $AT ) {
        sleep $step;
        $self->syncexitcode(undef);
        $r = $self->_sshSyncExecS( $cmd, $timeout );
        return $r
          if (
                ( defined( $self->syncexitcode ) )
            and ( $self->syncexitcode != -100 )     #timeout
            and ( $self->syncexitcode != 65280 )    #connect
          );
        $step++;
        my $ec = $self->syncexitcode;
        $ec = 'undef' unless ( defined( $self->syncexitcode ) );
        DEBUG "Sync attemp [$step], exit code is :[$ec], retry...";
    }
    return $r;
}

sub _sshSyncExecS {
    my ( $self, $cmd, $timeout ) = @_;
    my $cc =
        "ssh -o  'BatchMode yes' "
      . "-o 'AddressFamily inet' "
      . "-o 'ConnectTimeout=25' "
      . "-o 'UserKnownHostsFile=$UserKnownHostsFile' "
      . "-o 'StrictHostKeyChecking=no' "
      . "-o 'ConnectionAttempts=3' "
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
            print "*******************Killed by timeout !\n";
            die "alarm clock restart";
        };
        alarm $timeout;

        #do main action
        my $rawout = '';    # `$cc`;

        open( my $cmd, "$cc|" ) || confess "Execution failed: $!";
        while (<$cmd>) {
            my $s = $_;     # chomp;
            $rawout = $rawout . $s;
            unless ( $s =~ m/Warning:\sPermanently\sadded/ ) {
                $out = $out . $s;
            }
        }
        close $cmd;

        #TODO rechec in future difference between  $? and CHILD_ERROR_NATIVE
        #my $code = $?;

        alarm 0;            # cancel the alarm asap
    };
    alarm 0;                # race condition protection

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
        WARN "SSH exit code mean connection problem  ["
          . ${^CHILD_ERROR_NATIVE}
          . "](sync mode)";
        return undef;
    }

    #DEBUG "--------------";
    return $out;
}

sub _sshAsyncExec {
    my ( $self, $cmd, $timeout ) = @_;
    DEBUG "Xperior::SshProcess->_sshAsyncExec";
    my $asyncstarttimeout = 30;
    my $sc                = 1;
    my $cc =
        "ssh  -o  'BatchMode yes' "
      . "-o 'AddressFamily inet' "
      . "-o 'UserKnownHostsFile=$UserKnownHostsFile' "
      . "-o 'StrictHostKeyChecking=no' "
      . "-o 'ConnectTimeout=25' " . "-f "
      . $self->user . "@"
      . $self->host
      . " \"$cmd\"  ";
    DEBUG "Remote cmd is [$cc]";
    my $step = 0;
    my $AT   = 5;

    #this cycle is workaround for connection problem,
    #which observed too rare.
    while ( ( $sc != 0 ) and ( $step < $AT ) ) {
        $self->bprocess( Proc::Simple->new() );
        $self->bprocess->start($cc);
        $self->bprocess->kill_on_destroy(1);
        my $time = 0;
        while ( not defined $self->bprocess->exit_status() ) {
            DEBUG 'sleep 1 ' . `/bin/sleep 1`;    #hack, looks like perl's sleep
                                                  #doesn't work there
            $sc = $self->bprocess->exit_status();
            $time++;
            if ( $time > $asyncstarttimeout ) {
                ERROR "App alive more then $asyncstarttimeout seconds, kill it";
                $self->bprocess->kill;
            }
        }
        $sc = $self->bprocess->exit_status();
        DEBUG "[$step] local async result = [$sc]";
        $step++;
    }
    return $sc;
}

=head3 init ($host, $user, $port)

Initialize module. Protocol is only ssh.

=cut

sub initTemp {
    my $self = shift;
    my $id   = Time::HiRes::gettimeofday();
    $self->pidfile("/tmp/xperior_pid_ssh_$id");
    $self->ecodefile("/tmp/remote_exit_code_$id");
    $self->syncecodefile("/tmp/remote_sync_exit_code_$id");
    $self->rscrfile("/tmp/remote_script_$id.sh");

}

sub init {
    DEBUG "Automator::SshUnixProcess->init";
    my $self = shift;
    $self->host(shift);
    $self->user(shift);
    $self->port(shift);
    my $nocrash = shift;

    $self->initTemp;
    $self->killed(0);
    $self->exitcode(0);

    my $ver = '';
    $ver = $self->_sshSyncExec( "uname -a", 30 );
    $ver = '' unless defined $ver;
    chomp $ver;

    #DEBUG "-------------------------------";
    #DEBUG ${^CHILD_ERROR_NATIVE};
    #DEBUG $self->exitcode;
    #DEBUG $self->killed;
    if (   ( ${^CHILD_ERROR_NATIVE} != 0 )
        || ( $self->exitcode != 0 )
        || ( $self->killed != 0 )
        || ( $ver eq '' ) )
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

=head3 createSync ($command, $timeout)

Execute remote process and catch stderr/std and exit code. Function exit when remote execution done.

Function have one parameter - command for start on emote node.

=cut

sub createSync {
    my ( $self, $app, $timeout ) = @_;
    $self->appcmd($app);
    DEBUG "Xperior::SshProcess createSync";
    DEBUG "App to run [$app] on host[" . $self->host . "]";
    my $ecf = $self->syncecodefile;
    $self->killed(0);
    $self->syncexitcode(undef);
    my $ss = <<"SS";
$app
echo \\\$? > $ecf
SS

    my $tef = $self->rscrfile;
    my $fco = $self->_sshSyncExec("echo  '$ss' > $tef");

    my $s = $self->_sshSyncExec( "sh $tef", $timeout );
    DEBUG "Remote app completed";

    if ( $self->killed == 0 ) {
        my $ecfc = $self->_sshSyncExec("cat $ecf");
        if ( defined($ecfc) ) {
            chomp $ecfc;
            DEBUG "Exit code is [$ecfc]";
            $self->syncexitcode( trim $ecfc );
        }
        else {
            WARN
"No remote exit code is get, looks like connection problem observed, set undef";
            $self->syncexitcode(undef);
        }

        #$self->exitcode($self->syncexitcode);
    }
    return $s;

}

=head3 create ($name, $command)

Execute remote process with unattached stderr/stdout and exit. Pid is savednon remote fs. Exit code is saved after process end.

Parameters:

=over 4

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
    DEBUG "[$name]: Xperior::SshProcess create";
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

=head3 kill ($mode)

Kill process which was created by create via saved pid.

=cut

sub kill {
    my ( $self, $mode ) = @_;
    DEBUG "Xperior::SshProcess->kill";
    my $pid  = $self->pid;
    my $name = $self->appname;
    $mode = 0 unless defined $mode;

    if ( ( !defined($pid) ) or ( $pid eq '' ) ) {
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

=head3 isAlive

Check process status on remote system via saved pid. Also this function get exit code from remote side if application is exited or killed.

=cut

#sub isAlive {
#    DEBUG "Xperior::SshProcess->isAlive";
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
    DEBUG "Xperior::SshProcess->isAlive";
    my $self = shift;
    my $pid  = $self->pid;
    my $name = $self->appname;
    my $o;
    my $step     = 1;
    my $AT       = 6;
    my $exitcode = '';
    while ( $AT > $step ) {
        $o = $self->_sshSyncExec(" ps -o pid=  -p $pid h 2>&1; echo \$? ");
        if ( defined($o) ) {
            $o = trim $o;
        }
        if ( ( defined($o) ) and ( $o =~ m/^\s*$pid\s*/ ) ) {
            last;
        }
        $exitcode = trim( $self->_sshSyncExec( "cat " . $self->ecodefile ) );

        DEBUG "Exitcode = [$exitcode]";
        if ( ( defined($o) ) and ( $exitcode =~ m/^\d+$/ ) ) {
            last;
        }
        sleep $step;
        $step++;
        DEBUG "Proc is not found, <$step> recheck process status";
    }
    DEBUG "Alive check cycle done";

    #  DEBUG "*********** $o";
    unless ( defined($o) ) {
        ERROR "unable to check remote system, no output got";
        return -99;
    }

    if ( $o =~ m/^\s*$pid\s*/ ) {
        DEBUG "Remote process is alive! ";
        return 0;
    }
    $self->exitcode($exitcode);
    DEBUG "Remote process is not found, sync exit code is: ["
      . $self->syncexitcode
      . "], app exit code is :["
      . $self->exitcode
      . "], \n o=[$o]";
    return -1;
}

=head3 putFile ($local_file, $remote_file)

Put fileto remote system.

Return 0 if file copied and scp exit code if error occurred.

=cut

sub putFile {
    my ( $self, $localfile, $remotefile ) = @_;
    my $destination = $self->user . '@' . $self->host . ':' . $remotefile;
    DEBUG "Copying $localfile to $destination";
    runEx(  "scp -rp "
          . "-o 'UserKnownHostsFile=$UserKnownHostsFile' "
          . "-o 'StrictHostKeyChecking=no' "
          . "-o 'ConnectionAttempts=3' "
          . "-o 'ConnectTimeout=25' "
          . "$localfile $destination" );
}

=head3 getFile ($remote_file, $local_file)

Get file from remote system.

Return 0 if file copied and scp exit code if error occurred.

=cut

sub getFile {
    my ( $self, $rfile, $lfile ) = @_;
    my $source = $self->user . '@' . $self->host . ':' . $rfile;
    DEBUG "Copying [$source] to [$lfile]";

    return runEx( "scp -rp "
          . "-o 'UserKnownHostsFile=$UserKnownHostsFile' "
          . "-o 'StrictHostKeyChecking=no' "
          . "-o 'ConnectionAttempts=3' "
          . "-o 'ConnectTimeout=25' "
          . "$source $lfile" );
}

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

