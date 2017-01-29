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

Xperior::Executor::LustreHATests - Module which execute test
L<ha.sh|https://github.com/Xyratex/lustre-stable/blob/b_neo_stable_2.0/lustre/tests/ha.sh>


=head1 DESCRIPTION

The module contains Lustre ha.sh execution functionality

This module inherit L<Xperior::Executor::SingleProcessBase> and provide
functionality for generating command line  for Lustre ha.sh tests and parse
the tests output. Lustre test is executing on master client, minimal
lustre setup should defined: client node with C<'master: yes'>,
lustre servers.

Sample test descriptor there F<testds/lustre-ha_tests.yaml>, be sure that
you are set victim nodes for testing failover in test descriptor.

Test specific system descriptor options (additionaly to
L<Xperior::Executor::SingleProcessBase>)

    client_mount_point  : [path] # where client mounted
    tempdir             : [dir] #temp dir in client mount


Test specific test descriptor options (additionaly to
L<Xperior::Executor::SingleProcessBase>)

    options    :  -u 900  -p 30 #ha.sh parameters, passed just as string to command
    victims    :  kvm1n1c006 #comma-separated nodes list of victims nodes
    halogs     : oveeride default file list for collection and attachement

RTP-2119 RTP-2109

=cut

package Xperior::Executor::LustreHATests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;
use Xperior::Utils;
use Xperior::RemoteHelper;

extends 'Xperior::Executor::SingleProcessBase';

has 'script'              => ( is => 'rw', default => 'ha.sh');
has 'cleanup_before_run'  => ( is => 'rw', default => 1);
has 'lustretestdir'       => ( is => 'rw', default => '/usr/lib64/lustre/tests/');

=head3 getClientCount

Return count of lustre clients

=cut

sub getClientCount {
    my $self = shift;
    my $clients = $self->env->getLustreClients();
    return scalar( @$clients );
}

=over 12

=item B<_prepareCommands> - generate command line for Lustre ha.sh test
based on L<configuration|XperiorUserGuide/"System descriptor"> and
test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    #$self->_prepareEnvOpts;

    my $tempdir = $self->env->cfg->{'tempdir'} || 'hatest';
    my $ldir    = $self->env->cfg->{'client_mount_point'} . $tempdir;
    if((trim($ldir) eq '') or (trim($ldir) eq '/')){
        confess "Cannot prepare command for Lustre ha.sh, lustre root is [$ldir]";
    }
    #TODO define what should be done with ext env
    #my $eopts   = $self->env->cfg->{extoptions} || '';

    my $options = $self->test->getParam('options');
    my $victims = '';
    if(defined($self->test->getParam('victims'))){
        $victims = '-v '. $self->test->getParam('victims');
    }
    my $clients = join(',',
                map{
                     my $node = $_->{'node'};
                     $self->env->getNodeById($node)->ip();
                    } @{ $self->env->getLustreClients()}
                );
    DEBUG "Clients are [$clients]";
    $clients = "-c $clients" if $clients;
    my @allnodes =  @{$self->env->cfg->{'LustreObjects'}};
    my $servers = join(',',
                map{
                    my $node = $_->{'node'};
                    $self->env->getNodeById($node)->ip();
                }
                grep{
                    $_->{'type'} ne 'client'
                }@allnodes
            );

    $servers = "-s $servers" if $servers;
    my @envvars;
    my $env = $self->test->getMergedHashParam("env");
    if (ref($env) eq 'HASH') {
        for my $k (keys %$env) {
            push @envvars,
                "$k=\"" . $env->{$k} . "\"";
        }
    }


    DEBUG "Servers are [$servers]";
    my $cmd =join(' ',
        @envvars,
        $self->lustretestdir().$self->script(),
        $options,
        $clients,
        $servers,
        "-d $ldir ",
        $victims) ;
    if($self->cleanup_before_run()){
        $cmd = "rm -rf $ldir/* /tmp/ha.sh* && ".$cmd
    }
    $cmd = "mkdir -p $ldir && ".$cmd;
    $self->cmd(trim($cmd ));
}

=over 12

=item * B<processLogs> - collect log files

Find log files based on B<halogs>

    Log file : /tmp/ha.sh*/*
    dk file  : /tmp/ha.sh-*dk


These files will be downloaded (if possible) and attach to test

Return values:

    Xperior::Executor::Base::PASSED

Also failure reason accessible (if defined) via call C<getReason>.

=back

=cut

sub processLogs {
    my ( $self, $file ) = @_;
    my $halogs = $self->test->getParam('halogs');
    if(not $halogs){
         $halogs = \@{[
             '/tmp/ha.sh*/*',
             '/tmp/ha.sh*dk',
         ]}
    }
    DEBUG Dumper $self->_getMasterNode();
    DEBUG Dumper $self->env->getNodeById( $self->_getMasterNode()->{'node'}) ;
    DEBUG Dumper $halogs;
    collect_remote_files_by_mask(
        $self->env->getNodeById( $self->_getMasterNode()->{'node'}),
        $self,$halogs);
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
