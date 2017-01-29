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

Xperior::Executor::SingleProcessBase -
    base module for control remote execution

=head1 DESCRIPTION

This is base module for control remote execution of single process. Reused
 in several other modules which override functions.
Inherited fom L<Xperior::Executor::Base>

=head1 METHODS

=cut

package Xperior::Executor::SingleProcessBase;
use Moose;
use Data::Dumper;
use Carp qw(cluck);
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;
use Sys::Hostname;


use Xperior::SshProcess;
extends 'Xperior::Executor::Base';


=head3  execute

Function executes process on remote client and control remote execution
via ssh. Only one process could be executed by one object instance.
Process is executed  on first found client which marked as master.

Sample of master client definition from system configuration

    LustreObjects:
      - id: client1
        master: yes
        node: fre1107
        type: client

If more them one client is defined as master first found client
will be used.


Command line for executing  should be prepared in inheritor by
defining B<_prepareCommands> function.

Process is executed via asynchronous call from L<Xperior::SshProcess>.

When remote process is not found observation stops and execution
status is calculating. Status set by results from B<processLogs>
function, 'killed' and connection issue status, worse status
is selected. Also process stderr and stdout is saved as test logs.

Options of test object which are used

    cmd      - ready command line
    id       - test id
    timeout  - common timeout for test(process)

Options of environment which are used

    client_mount_point - mount point on client


=cut


sub execute {
    my $self    = shift;
    #get remote processor
    $self->addYE( 'xperior_host', hostname);
    my $mnodecfg = $self->_getMasterNode();
    my $mclientobj = $self->env->getNodeById( $mnodecfg->{'node'} );
    my $testproc   = $mclientobj->getRemoteConnector();
    unless ( defined($testproc) ) {
        ERROR 'Master client obj is:' . Dumper $mclientobj;
        confess "SSH to master client is undef";
    }
    if(defined($self->env()->cfg()->{'test_start_attempts'})){
        $testproc->start_attempts(
            $self->env->cfg()->{'test_start_attempts'}
        );
    }
    if(defined($self->env()->cfg()->{'ssh_poll_timeout'})){
        $testproc->ssh_default_timeout(
            $self->env()->cfg()->{'ssh_poll_timeout'}
            );
    }
    #saving env data
    $self->addYE( 'masterclient', $mnodecfg->{id});
    $self->addYE( 'masterclient_host', $mnodecfg->{ip});
    DEBUG "Master Node:" . Dumper $mnodecfg;
    if($self->can('getClientCount')){
        $self->addYE('client_count', $self->getClientCount());
    }
    $self->_prepareCommands($testproc);
    $self->_addCmdLogFiles;
    $self->addYE( 'cmd', $self->cmd );

    $self->prepare_node();


    ##remove and recreate directory for logs
    #TODO cleanup should be done out of sub execute
    #$testp->createSync ('rm -rf /var/log/xperior/');

    my $mountpoint = $self->env->cfg->{'client_mount_point'}
      or cluck("Undefined 'client_mount_point'");
    my @cmds = (
        'mkdir -p /var/log/xperior/',
        "mkdir -p ${mountpoint}",);

    $testproc->run(\@cmds);

    #TODO add exit value check there. Now it doesn't have value until
    #own lustre mount manager

    my $starttime = time;
    $self->addYE( 'starttime', $starttime );

    my $cr = $testproc->create( $self->appname, $self->cmd );
    if ( $cr < 0 ) {
        $self->fail_on_cannot_execute($testproc, "master client",'');

        return;
    }

    $self->wait_cycle($self, $starttime, $testproc);

    $self->execution_result_calculation($self, $testproc, $mclientobj, $starttime);
    #cleanup tempdir after execution
    #TODO make this removing safe!!!
    $testproc->run( 'rm -rf ' . "$mountpoint/*" )
            if ($mountpoint and $mountpoint ne "");


    #$self->test->tap     ( $self->tap);
    $self->test->results( $self->yaml );
    $self->cleanup($testproc);
    $self->clean_nodes();
    #no idea what is good result there, so no return
    return;
}

sub cleanup {
    my $self = shift;
}
sub clean_nodes{
    my $self = shift;
}

sub getReason {
    my $self = shift;
    return $self->reason;
}

sub processSystemLog{
    my ( $self, $connector, $filename ) = @_;
    WARN 'processSystemLog is not implemented';
}

sub prepare_node{
    my $self = shift;
}

=item * _getMasterNode - retruns master node where test process will be executed

It's important to use this call for getting master node in childs. Current implementation
is Lustre-oriented but child could override it

=cut

sub _getMasterNode{
    my $self = shift;
    return $self->env->getMasterLustreClient();
}

sub _getMasterConnector{
    my $self = shift;
    my $mclient    = $self->_getMasterNode();
    my $mclientobj = $self->env->getNodeById($mclient->{'node'});
    my $connector  = $mclientobj->getRemoteConnector();
    return $connector;
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

