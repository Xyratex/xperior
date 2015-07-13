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
# Copyright 2015 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#
=pod

=head1 NAME

Xperior::Executor::MultiNodeSingleProcess - Definition
of multi test executor

=head1 DESCRIPTION

Class is inheritor of L<Xperior::Executor::Base> for
cumulative results for all process.

Class uses L<Xperior::SubTestResult> for keep test
result per process.

This executor is resposible for executing test which is
oriented to execution on multiple nodes, one process
per one node.


=head1 FUNCTIONS


=cut

package Xperior::Executor::MultiNodeSingleProcess;
use strict;
use warnings FATAL => 'all';
use Moose;
use Data::Dumper;
use Carp qw(cluck);
use File::Path;
use Log::Log4perl qw(:easy);
use File::Copy;
use threads;

use Xperior::SshProcess;
use Xperior::SubTestResult;

extends 'Xperior::Executor::Base';

=head3  execute

Function executes processes on client and observe/control process
execution via ssh. Process is executed on all clients marked as
B<target>:

    GenericObjects:
       - id          : client1
         node        : local1
         type        : client
         target      : yes

       - id          : client2
         node        : local1
         type        : client
         target      : yes

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

sub execute{
    my $self = shift;
    my @targets = @{$self->_get_targets()};

    #saving env data
    ##TODO
    ##DEBUG "Master Node:" . Dumper $mnodecfg;

    $self->addYE( 'cmd', $self->cmd );

    #get remote processors
    #connectors array have same index as targets
    my @test_conenctors;
    foreach my $t (@targets){
        print Dumper $t;
        my $clientobj = $self->env->getNodeById( $t->{'node'} );
        my $testproc   = $clientobj->getExclusiveRC();
        unless ( defined($testproc) ) {
            ERROR 'Target client obj is:' . Dumper $clientobj;
            confess "SSH to master client is undef";
        }
        $t->{connector} =  $testproc;
        $t->{nodeobj}   = $clientobj;
        push @test_conenctors, $testproc;
     }
    my $mountpoint = $self->env->cfg->{'client_mount_point'}
      or cluck("Undefined 'client_mount_point'");

    #node preparation
    my @threads = ();
    foreach my $connector ( @test_conenctors ) {
      push @threads, threads->create(\&_prepare_node, $self, $connector,$mountpoint);
    }
    threads->yield;
    foreach my $t (@threads){
        my $res = $t->join();
        if($res->{exitcode} != 0){
            confess("Cannot prepare node, exitingt".
                    "\nstdout=".$res->{'stdoutraw'}.
                    "\nstderr=".$res->{'stderrraw'}
            );
        }
    }
    DEBUG 'Preparation completed';

    # main execution block
    my $starttime = time;
    my $endtime = $starttime + $self->test->getParam('timeout');
    $self->addYE( 'starttime', $starttime );

    @threads = ();
    foreach my $t ( @targets ) {
      push @threads, threads->create(\&_run_test, $self, $t);
    }
    threads->yield;
    my @results;
    foreach my $t (@threads){
        my $res = $t->join();
        DEBUG Dumper ($res);
        $self->addYEE( 'subtests','subtest_'.$res->yaml()->{id}, $res->yaml());
        push @results, $res;
    }

    $self->addYE( 'endtime',         time );
    $self->addYE( 'endtime_planned', $endtime);
    DEBUG 'Execution completed';

    #TODO cleanup tempdir after execution
    # it should be testing safe, remove only own data
    # maybe it's good idea implement in child
    #make this removing safe!!!
    #$testproc->run( 'rm -rf ' . "$mountpoint/*" )
    #        if ($mountpoint and $mountpoint ne "");
    my $pr = $self->NOTSET;
    foreach my $res (@results){
        $self->accumulate_resolution(
                $res->internal_result_code(),
                $res->reason()
                );
    }


}


sub _run_test{
    my ($self, $target) = @_;
    my $result = Xperior::SubTestResult->new();
    my %y = ();#(node => $target);
    $result->yaml(\%y);
    $result->owner($self);
    $result->options($self->options());
    #customizing there
    $self->_prepareCommands();
    $result->cmd($self->cmd);
    #$result->cmd($self->test->getSubTestParam('cmd'));
    my $starttime = time;
    my $id = $target->{id};
    my $testproc = $target->{connector};
    $result->_addCmdLogFiles;
    $result->addYE( "id", $id );
    $result->addYE( "starttime", $starttime );
    $result->addYE( "cmd", $result->cmd );
    #TODO set sync point there
    my $cr = $testproc->create( $self->appname, $result->cmd );
    if ( $cr < 0 ) {
        $result->fail_on_cannot_execute($testproc,"target [${id}] client",$id.'.');
        return $result;

    }
    $self->wait_cycle($result, $starttime, $testproc, "[$id]");

    $self->execution_result_calculation($result, $testproc, $target->{nodeobj}, $starttime, $id.'.', "[$id]");
    return $result;
}

sub _prepare_node{
    my ($self, $connector, $mountpoint) = @_;
    my @cmds = (
        'mkdir -p '.$self->xp_log_dir(),
        "mkdir -p ${mountpoint}",);
    return $connector->run(\@cmds);
}

sub _get_targets{
    my $self = shift;
    return $self->env->get_target_generic_clients();
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