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
our $VERSION = '0.02';

has need_verification   => ( is => 'rw', default => 1);


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

    $self->addYE( 'cmd', $self->cmd );

    #get remote processors
    #connectors array have same index as targets
    my @test_conenctors;
    my @clnt_nodes;
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
        push @clnt_nodes, $clientobj;
     }
    my $mountpoint = $self->env->cfg->{'client_mount_point'}
      or cluck("Undefined 'client_mount_point'");

    #preparation status check
    my $results_prepare_nodes =
            $self->prepare_nodes(\@test_conenctors, \@targets, );
    my $pr = $self->NOTSET;
    foreach my $res (@{$results_prepare_nodes}){
        $self->accumulate_resolution(
                $res->internal_result_code(),
                $res->reason()
                );
    }
    if($self->internal_result_code != $self->PASSED){
        return;
    }

    # main execution block
    my $starttime = time;
    my $endtime = $starttime + $self->test->getParam('timeout');
    $self->addYE( 'starttime', $starttime );
    my $results = $self->run(\@targets);


    $self->addYE( 'endtime',         time );
    $self->addYE( 'endtime_planned', $endtime);
    DEBUG 'Execution completed';
    foreach my $res (@{$results}){
        $self->accumulate_resolution(
                $res->internal_result_code(),
                $res->reason()
                );
    }
    if($self->internal_result_code != $self->PASSED){
        return;
    }

    #verifying
    if($self->need_verification()){
        my $results_verify = $self->verify(\@targets);
        foreach my $res (@{$results_verify}){
            $self->accumulate_resolution(
                    $res->internal_result_code(),
                    $res->reason()
                    );
        }
        if($self->internal_result_code != $self->PASSED){
            return;
        }
    }

    #FIXME cleanup tempdir after execution
    # it should be testing safe, remove only own data
    # maybe it's good idea implement in child
    #make this removing safe!!!
    #$testproc->run( 'rm -rf ' . "$mountpoint/*" )
    #        if ($mountpoint and $mountpoint ne "");
}

sub run{
    my ($self, $targets)= @_;
    my @threads = ();
    my $i=0;
    foreach my $t ( @{$targets} ) {
        DEBUG "Run test core on $t";
        push @threads, threads->create(\&run_test, $self, $t, $i);
        $i++;
    }
    #return \@threads;
    threads->yield;
    my @results;
    foreach my $t (@threads){
        my $res = $t->join();
        $self->addYEE( 'subtests','subtest_'.$res->yaml()->{id}, $res->yaml());
        push @results, $res;
    }
    return \@results;
}

sub verify{
    my ($self, $targets)= @_;
    DEBUG 'Start verifying';
    my @threads = ();
    foreach my $t ( @{$targets} ) {
      push @threads, threads->create(sub {
                    $self->verify_node($t)});
    }
    threads->yield;
    my @results;
    foreach my $t (@threads){
        my $res = $t->join();
        $self->addYEE( 'subtests_verify','subtest_'.$res->yaml()->{id}, $res->yaml());
        push @results, $res;
        #FIXME exit codes shoudl be checked!
    }
    return \@results;
}

sub run_test{
    my ($self, $target, $thr_num) = @_;
    my $result = Xperior::SubTestResult->new();
    my %y = ();#(node => $target);
    $result->yaml(\%y);
    $result->owner($self);
    $result->options($self->options());
    #customizing there
    $self->_prepareCommands($target, $thr_num);
    $result->cmd($self->cmd);
    #FIXME it's workaround!!!!
    $result->addYE('datafile',$self->yaml->{'datafile'})
                    if(defined($self->yaml->{'datafile'}));
    $result->addYE('outfile',$self->yaml->{'outfile'});

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

#parallel nodes preparation
sub prepare_nodes{
    my ($self, $test_conenctors, $targets) = @_;
    #FIXME in future it could be different
    my $mountpoint = $self->env->cfg->{'client_mount_point'}
                      or cluck("Undefined 'client_mount_point'");
    my @threads = ();
    my $i=0;
    foreach my $connector ( @{$test_conenctors} ) {
        #my $clnt = $clnt_nodes[$i];
        my $t = @{$targets}[$i];
        push @threads, threads->create(sub {
                    $self->prepare_node(
                                $t,
                                $connector,
                                $mountpoint)});
        $i++;
    }
    threads->yield;
    my @results;
    foreach my $t (@threads){
        my $res = $t->join();
        $self->addYEE(
            'subtests_prepare',
                'subtest_'.$res->yaml()->{id},
                    $res->yaml());
        #FIXME exit codes shoudl be checked!
        push @results, $res;
#        if($res != 0){
#            confess("Cannot prepare node, exitingt".
#                    "\nstdout=".$res->{'stdoutraw'}.
#                    "\nstderr=".$res->{'stderrraw'}
#            );
#        }
    }
    #TODO add preparation status check
    #DEBUG 'Preparation completed';
    #return $self->PASSED;
    return \@results;
}

sub prepare_node{
    my ($self, $t, $connector, $mountpoint) = @_;
    my $result = Xperior::SubTestResult->new();
    my %y = ();
    $result->yaml(\%y);
    $result->owner($self);
    $result->addYE( "id", $t->{id} );

    my @cmds = (
        'mkdir -p '.$self->xp_log_dir(),
        "mkdir -p ${mountpoint}",);
    $result->addYE("cmd",join(';',@cmds));
    my $res = $connector->run(\@cmds, timeout=>600);#->{exitcode};
    $result->addYE("exitcode",$res->{exitcode});
    if($res->{exitcode} ==0 ){
        $result->pass();
    }else{
        $result->fail('Cannot prepared node');
    }
    return $result;
}

sub processSystemLog{
    #default empty implemnetation
    #should be ovewritten where real code defined
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
