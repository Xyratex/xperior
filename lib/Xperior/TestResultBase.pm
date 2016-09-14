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
# Copyright 2015 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#
=pod

=head1 NAME

Xperior::TestResultBase - Base test result class

=head1 DESCRIPTION

Class contains core set of variables and methonds for test
result.

Keep all test results to field B<yaml>. This class describes only
memory-only behavior without storing.

Class defines test result values and it's constants.
Be aware: yaml result codes is not same to class result codes
because external(yaml) codes dictated by TAP which has
historical non-useful codes. (about TAP see inheritor
L<Xperior::Executor::Base>

=head1 FUNCTIONS


=cut


package Xperior::TestResultBase;
use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Path;
use File::Copy;
use File::Slurp;
use Carp;

use YAML;

has DEFAULT_POLL => ( is => 'ro', default => 5 );

has PASSED       => ( is => 'ro', default => 0 );
has SKIPPED      => ( is => 'ro', default => 1 );
has FAILED       => ( is => 'ro', default => 10 );
has NOTSET       => ( is => 'ro', default => 100 );    #also failed

has 'result_code'          => ( is => 'rw', default => -1 );
has 'internal_result_code' => ( is => 'rw', default => 100 );
has 'result'               => ( is => 'rw', default => 'not set');
has 'reason'               => ( is => 'rw' );


has yaml         => (is => 'rw');
has cmd          => (is=>'rw');
has remote_out   => (is =>'rw');
has remote_err   => (is =>'rw');
has options      => ( is => 'rw');

=head2 addYE(KEY, VALUE)

Adds Yaml Element.

Returns 1 if the value has been overridden, otherwise returns 0.

=cut

sub addYE{
    my ($self, $key, $value) = @_;
    my $overridden = defined $self->yaml->{$key};
    $self->yaml->{$key} = $value ;
    $self->_write;
    return $overridden;
}

=head2 addYEE(KEY1, KEY2, VALUE)

Adds Yaml Element in Element. Means adding second level hash element.

Returns 1 if the value has been overridden, otherwise returns 0.

=cut

sub addYEE{
    my ($self, $key1, $key2, $value) = @_;
    my $overridden = (defined $self->yaml->{$key1} and
                      defined $self->yaml->{$key1}->{$key2});
    $self->yaml->{$key1}->{$key2} = $value ;
    $self->_write;
    return $overridden;
}

=head2 addMessage

Save message to tests. User for message frpm Xperior, e.g.
"Master client down". Saved in result yaml.

=cut

sub addMessage{
    my ($self,$data) = @_;
    $self->yaml->{'messages'}='' unless defined $self->yaml->{'messages'};
    $self->yaml->{'messages'} =
                $self->yaml->{'messages'} . $data."\n"
                    if defined $data;
    $self->_write;
}

=head2 pass

Set test passed.

=cut

sub pass{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->result("ok 1 $msg");
    $self->result_code(0);
    $self->internal_result_code($self->PASSED);
    $self->yaml->{'status'} = 'passed';
    $self->yaml->{'status_code'} = 0;
    $self->_write;
}

=head2 fail

Set test failed.

=cut

sub fail{
    my ($self,$msg)  = @_;
    my $pmsg = $msg;
    if((defined $msg) and ($msg ne '')){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->result("not ok 1 $msg") ;
    $self->result_code(1);
    $self->internal_result_code($self->FAILED);
    $self->yaml->{'status'} = 'failed';
    $self->yaml->{'status_code'} = 1;
    $self->yaml->{'fail_reason'} = $pmsg;
    $self->reason($pmsg);
    $self->_write;
}

=head2 skip

Set test skipped

=cut

sub skip{
    #mode means type of skip - skip may
    # be acc-sm induced or exclude list induced
    my ($self,$mode,$msg)  = @_;
    if( defined $msg){
        $msg = " #".$msg
    }else{
        $msg='';
    }
    $self->result("ok 1# SKIP $msg") ;
    $self->result_code(2);
    $self->internal_result_code($self->SKIPPED);
    $self->yaml->{'status'} = 'skipped';
    $self->yaml->{'status_code'} = 2;
    $self->yaml->{'fail_reason'} = $msg;
    $self->reason($msg);
    $self->_write;
}

=head2 accumulate_resolution

Calculate new status based on previous status.
It's used for accumulating status for multistep tests

=cut

sub accumulate_resolution{
    my ($self,$status_internal,$msg)  = @_;
    if( $self->internal_result_code() < $status_internal
        || $self->internal_result_code() == $self->NOTSET){
        if($status_internal == $self->PASSED){
            $self->pass($msg)
        }elsif($status_internal == $self->SKIPPED){
            $self->skip('',$msg)
        }else{
            $self->fail($msg)
        }
    }else{
        DEBUG "Keep previous status:".$self->internal_result_code();
    }
}

sub fail_on_cannot_execute{
        my ($self, $testproc, $nodename_msg,$log_prefix)  = @_;
        $self->fail(
            'Cannot start or find just started remote test '.
            "process on $nodename_msg"
        );
        $self->addMessage(
            'Cannot start remote process, network or remote host problem '.
             "for $nodename_msg");
        #$result->test->results( $self->yaml );
        $self->addYE( "targethostdown", 'yes' );
        $self->addYE( "killed",         'no' );
        $self->_getLog( $testproc, $self->remote_err, 'stderr', "${log_prefix}stderr" );
        $self->_getLog( $testproc, $self->remote_out, 'stdout', "${log_prefix}stdout" );
}

sub wait_cycle{
    my ($self, $result, $starttime, $testproc, $id_prefix)  = @_;
    $id_prefix='' unless defined $id_prefix;
    my $endtime = $starttime + $self->test->getParam('timeout');
    my $polltime = $self->test->getParam('polltime') || $self->DEFAULT_POLL;
    DEBUG "${id_prefix}Poll time is [$polltime]";
    while ( $endtime > time ) {
        #monitoring timeout
        sleep $polltime;
        if ( $testproc->isAlive() != 0 ) {
            DEBUG "${id_prefix}Remote app is not alive, exiting";
            last;
        }
        DEBUG "${id_prefix}Test alive, next wait cycle";
    }
    $result->addYE( "endtime",         time );
    $result->addYE( "endtime_planned", $endtime );
}

sub execution_result_calculation{
    my ($self, $result, $testproc, $node, $starttime, $id_prefix, $msg_prefix)  = @_;
    $id_prefix='' unless defined $id_prefix;
    $msg_prefix='' unless defined $msg_prefix;
    my $killed     = 0;
    my $isnodedown = 0;
    my $killtime   = 0;
    my $rc         = 0;
    my $ping       = $node->ping();
    if ( $ping and ( $testproc->isAlive() == 0 ) ) {
        WARN "SubTest is alive after end of test execution, kill it";
        my $ts = $node->getRemoteConnector();
        DEBUG $ts->createSync('ps afxo pid,pgid,tty,stat,time,cmd');

        $testproc->kill_tree();
        $killed = 1;

        $killtime = $testproc->killed;
    }
    elsif ( not defined($ping) ) {
        $isnodedown = 1;
        $result->addMessage(
            'Incorrect master host ip or cannot resolve dns name');
    }
    elsif ( $ping == 0 ) {
        $isnodedown = 1;
        $result->addMessage('Master host is down');
    }

    $result->addYE( 'completed', 'yes' );
    DEBUG "${msg_prefix}*****After crash check:" . $testproc->exitcode;

    my $pr = $self->NOTSET;
    my $getlogres = $result->_getLog( $testproc, $result->remote_out,
                                        'stdout',"${id_prefix}stdout" );
    if ( $getlogres == 0 ) {
        $pr = $self->processLogs($self->getNormalizedLogName('stdout'));
    }else {
        $result->reason(
            "Cannot get log file [" . $result->remote_out . "]: $getlogres" );
    }
    $getlogres = $result->_getLog( $testproc, $result->remote_err,
                                              'stderr',"${id_prefix}stderr" );
    if ( $pr == $self->NOTSET && $getlogres == 0) {
        $pr = $self->processLogs($self->getNormalizedLogName('stderr'));
    }
    elsif ( $getlogres != 0 ) {
        $result->reason(
            "Cannot get log file [" . $result->remote_err . "]: $getlogres" );
    }

    #calculate results status
    if ( $killed > 0 ) {
        $result->addYE( 'killed',         'yes' );
        $result->addYE( 'masterhostdown', 'no' );
        my $lifetime = $killtime - $starttime;
        $result->fail("Killed by timeout after [$lifetime] sec of execution");
    }
    elsif ( $isnodedown > 0 ) {
        $result->addYE( 'masterhostdown', 'yes' );
        $result->addYE( 'killed',         'no' );
        $result->fail('Master host became down just after or while testing');
    }
    else {
        $result->addYE( 'killed',         'no' );
        $result->addYE( 'masterhostdown', 'no' );
        $result->addYE( 'exitcode',       $testproc->exitcode );
        DEBUG "testproc->exitcode=[".$testproc->exitcode. "]  &&  pr = [$pr]";
        if ( ( $testproc->exitcode == 0 ) && ( $pr == $self->PASSED ) ) {
            $result->pass;
        }
        elsif ( ( $testproc->exitcode == 0 ) && ( $pr == $self->SKIPPED ) ) {
            $result->skip( 1, $self->getReason );
        }
        elsif ( ( $testproc->exitcode != 0 ) && ( $pr == $self->PASSED ) ) {
            $result->fail(
                "Test return non-zero exit code :" . $testproc->exitcode );
        }
        else {
            $result->fail( $self->getReason );
        }
    }
    return $result;
}

sub registerLogFile{
    my ($self,$key,$path)  = @_;
    my $rd=$self->_reportDir().'/';
    $path =~ s/$rd//;
    $self->addYEE('log',$key,$path);
}

sub normalizeLogPlace{
    my ($self,$lfile,$key,$ext)  = @_;
    $ext = 'log' unless ( $ext );
    return move ("$lfile",
            $self->_resourceFilePrefix()."$key.$ext");
}

sub getNormalizedLogName{
    my ($self,$key, $ext)  = @_;
    $ext = 'log' unless ( $ext );
    $self->_createDir();
    return $self->_resourceFilePrefix()."$key.$ext";
}

sub createLogFile{
    my ($self,$key, $ext)  = @_;
    $ext = 'log' unless ( $ext );
    my $file = $self->_resourceFilePrefix()."$key.$ext";
    $self->_createDir();
    my $fd;
    open $fd, "> $file" or
        confess "Cannot create log file[$file]:".$!;
    $self->registerLogFile($key,$file, $ext);
    return $fd;
}

sub writeLogFile{
    my ($self,$key, $data, $ext)  = @_;
    $ext = 'log' unless ( $ext );
    my $file = $self->_resourceFilePrefix()."$key.$ext";
    $self->_createDir();
    my $res = write_file ($file,$data);
    if($res != 1){
        ERROR "Cannot write log file[$file] with error code [$res]";
        return 0;
    }
    $self->registerLogFile($key,$file, $ext);
    return $res;
}

sub _createDir{
    my $self = shift;
    if ( ! -d $self->_reportDir){
        mkpath ($self->_reportDir);
    }
}


sub _getLog {
    my ( $self, $connector, $remote_log_file, $log_name, $local_log_name ) = @_;
    $local_log_name = $log_name unless defined $local_log_name;
    my $res =
      $connector->getFile( $remote_log_file,
        $self->getNormalizedLogName($local_log_name));
    if ( $res == 0 ) {
        $self->registerLogFile( $log_name,
            $self->getNormalizedLogName($local_log_name) );
    }
    else {
        $self->addMessage( "Cannot copy log file [${remote_log_file}]: $res" );
    }
    return $res;
}

sub _addCmdLogFiles {
    my $self = shift;
    my $r    = int rand 1000000;
    my $tee  = " | tee ";

    confess 'No cmd found, cannot continue' unless $self->cmd;
    $self->options->{'cmdout'} = 0
      unless defined $self->options->{'cmdout'};

    $tee = " 1>  " if $self->options->{'cmdout'} == 0;
    #FIXME hardcoded path
    $self->remote_err("/var/log/xperior/test_stderr.$r.log");
    $self->remote_out("/var/log/xperior/test_stdout.$r.log");
    $self->cmd( $self->cmd
          . " 2>     "
          . $self->remote_err
          . $tee
          . $self->remote_out );
    return;
}


__PACKAGE__->meta->make_immutable;

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

Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

