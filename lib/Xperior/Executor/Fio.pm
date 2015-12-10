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


package Xperior::Executor::Fio;
use strict;
use warnings FATAL => 'all';
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;

extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = '0.01';
has io_size_per_client => (is => 'rw', default => '8T');
has io_block_size          => (is => 'rw', default => '128M');
has test_duration          => (is => 'rw', default => '5m');
has test_type              => (is => 'rw', default => 'write');
has threads_per_client     => (is => 'rw', default => '10');
has file_prefix            => (is => 'rw', default => 'fio_data_file');
has fio_binary             => (is => 'rw', default => 'fio');
has file_lid               => (is => 'rw', default => '13');
has testfilelist           => (is => 'rw');
has targetconnectors       => (is => 'rw');

sub _get_fio_config_file{
    my ($self, $thr_num) = @_;
    my $mount_point = $self->env->cfg->{'client_mount_point'};
#see refs/heads/dev/dev2-demo scripts/demo/2015-10-dev2.sh
my $cfg = <<CFG
# tested with patched fio-2.2.10
[global]
name=Concurrent write test
directory=$mount_point
fallocate=none
fadvise_hint=0
size=$self->{io_size_per_client}
blocksize=$self->{io_block_size}
blockalign=$self->{io_block_size}
direct=1
overwrite=1
end_fsync=0
fsync_on_close=0
do_verify=0
invalidate=0
allow_file_create=0
create_on_open=0
file_append=1
clat_percentiles=1

[write]
runtime=$self->{test_duration}
readwrite=$self->{test_type}
numjobs=$self->{threads_per_client}
thread
group_reporting
ioengine=sync
filename_format=$self->{file_prefix}$thr_num\$jobnum
buffer_pattern=0x0
wait_for_previous

CFG
;
return $cfg;
}


sub _prepareCommands{
    my ($self, $master_connector) = @_;
    my $tmpdir = $self->env->cfg->{'tempdir'};
    my $mount_point = $self->env->cfg->{'client_mount_point'};
    my @targets = @{$self->_get_targets()};
    my $target_num=0;
    #DEBUG Dumper @targets;
    my (@cmd, @touchfilelist);
    push @cmd, $self->fio_binary();
    foreach my $t (@targets){
        for(my $j=0; $j <$self->{threads_per_client}; $j++ ){
            push @touchfilelist,
                "${mount_point}/$self->{file_prefix}${target_num}$j";

        }
        my $config_file_content = $self->_get_fio_config_file($target_num);
        my $config_file_name = "fio_config_file$target_num";
        $self->writeLogFile($config_file_name,$config_file_content);
        my $res = $master_connector->putFile(
            $self->_resourceFilePrefix."${config_file_name}.log",
            "${tmpdir}/${config_file_name}"
        );
        if($res != 0){
            confess "Cannot copy config file to master node";
        }
        $target_num++;
        my $nodeobj = $self->env->getNodeById($t->{'node'});
        push @cmd, '--client='.$nodeobj->ip(),
                    "${tmpdir}/${config_file_name}";
    }
    my @fullcmd;
    push @fullcmd,
            ' sh -c " rm -f', @touchfilelist, '&&',
            'touch', @touchfilelist, '&&',
            "setfattr -n lid -v",$self->file_lid(),@touchfilelist,'&&',
            'fio',
            $self->test->getParam('cmd'),
            @cmd, '"';
    #DEBUG 'cmd='. Dumper @fullcmd;
    $self->cmd(join(' ', @fullcmd));
    $self->testfilelist(\@touchfilelist);
    DEBUG $self->cmd();
}

sub _getMasterNode{
    my $self = shift;
    return $self->env->get_master_generic_clients();
}

sub prepare_node{
    my $self = shift;
    my @targets = @{$self->_get_targets()};
    my @targetconnectors;
    foreach my $t (@targets){
        my $clientobj = $self->env->getNodeById( $t->{'node'} );
        my $testproc   = $clientobj->getExclusiveRC();
        unless ( defined($testproc) ) {
            ERROR 'Target client obj is:' . Dumper $clientobj;
            confess "SSH to master client is undef";
        }
        push @targetconnectors, $testproc;
        $testproc->run('killall -9 fio');
        my $res =
            $testproc->create('fio-server',$self->fio_binary().' --server');
        if( $res != 0 ){
            confess "Cannot run [".
                $self->fio_binary()." --server] on [".$t->{'node'}."]";
        }
        sleep 1;#time for failing while initializing
        if ($testproc->isAlive() != 0){
            confess 'Fio server process already ended';
            #TODO collect sever logs there!
        }
        $self->addMessage("fio server started on ".$t->{'node'});
        #exit 0;
     }
     $self->targetconnectors(\@targetconnectors);
}

sub cleanup {
    my ($self, $master) = @_;
    my @cmd;
    push (@cmd, 'rm -f', @{$self->testfilelist()});
    $master->run(join(' ', @cmd));
}

sub clean_nodes{
    my $self = shift;
    foreach my $proc (@{$self->targetconnectors}){
        $proc->kill();
        $proc->run('killall -9 fio');
    }
}

sub getReason {
    my $self = shift;
    return $self->reason;
}

sub processLogs{
    my $self    = shift;
    return $self->PASSED;
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

