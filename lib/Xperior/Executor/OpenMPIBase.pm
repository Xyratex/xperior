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

Xperior::Executor::OpenMPIBase - Module which contains OpenMPI specific 
execution functionality

=head1 DESCRIPTION

B<OpenMPI>  module for Xperior harness. Provides fuctions for command
 line support

=cut

package Xperior::Executor::OpenMPIBase;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );

extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = "0.0.2";

has mfile   => (is=>'rw');
has clients => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        addClient    => 'push',
        getClients   => 'elements',
    },
);
has machines => (is=>'rw');
has cmdfield => (is=>'rw');

=head2 METHODS

=head3 execute

I<execute> is inherit from Xperior::Executor::SingleProcessBase class.

=head3 reset

Reset previously generated values, f.e. clients list.

=cut

sub reset{
    my $self    = shift;
    my $clients = $self->env->getClients;
    $self->cmd('');
    my @e;
    $self->clients(\@e);
}


=head3 _prepareCommands

_prepareCommands - generate commands for executing cmd in  openmpi  environment.

=cut
sub _prepareCommands{
    my $self    = shift;
    $self->reset;

    #no any filtering now, create list of clients nodes
    foreach my $lc (@{$self->env->getClients}){
        my $nid = $lc->{'node'};
        my $ad = $self->env->getNodeAddress($nid);
        $self->addClient($ad);
    }
    my %csh;
    foreach my $c ($self->getClients){
        $csh{$c}=1;
    }
    my $mf = '';
    foreach my $c ( keys %csh){
        $mf = "$mf," if $mf ne '' ;
        $mf = $mf."$c";
    }
    $self->machines($mf);
    my $mp = $self->env->cfg->{'client_mount_point'};
    my $tf = $self->env->cfg->{'benchmark_tests_file'};
    my $td = $self->env->cfg->{'tempdir'}
    ;
    my $c = $self->test->getParam( $self->cmdfield );

    $c =~ s/\@mount_point\@/$mp/g;
    $c =~ s/\@test_file\@/$tf/g;
    $c =~ s/\@tempdir\@/$td/g;

    $self->cmd("/usr/lib64/openmpi/bin/mpirun  -H ".$self->machines." -pernode  --prefix /usr/lib64/openmpi/  $c");
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

