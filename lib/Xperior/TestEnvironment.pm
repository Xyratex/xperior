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

Xperior::TestEnvironment - Class maintains test environment and configuration.

=head1 DESCRIPTION

This class gathers cluster configuration data, disk sizes, space available, network type, cpu count, that nodes are reachable via ssh/pdsh, and Lustre basic liveness (Lustre is up and files can be created).

Also this class contains and can process system configuration which is read from external file.

=cut

package Xperior::TestEnvironment;

use Moose;
use Xperior::Node;
use Log::Log4perl qw(:easy);
use Carp;
use Data::Dumper;

has 'nodes'      => ( is => 'rw',isa => 'ArrayRef[]', );
has 'cfg'    => ( is => 'rw');

=head2 Public fields and supported constructor parameters

=head3 init(yamlobj)

Class initialization method

The yamlobj must be Xperior configuration
yaml data. See Xperior user guide.

Return

=cut

sub init{
    my $self = shift;
    my $yamlcfg = shift;
    $self->cfg($yamlcfg);
    $self->initNodes($self->cfg->{'Nodes'});
}

sub initNodes {
    my $self = shift;
    my $nodeArrayRef = shift;
    foreach my $n (@{$nodeArrayRef}) {
        my $node = Xperior::Node->new;
        $node->id($n->{'id'});
        $node->ip($n->{'ip'});
        $node->ctrlproto( $n->{'ctrlproto'});
        $node->user( $n->{'user'});
        $node->pass($n->{'pass'});
        $node->console($n->{'console'});

        push @{$self->{'nodes'}}, $node;
    }
}

sub checkEnv{
    DEBUG "Start env check";
    my $self = shift;

    #TODO
    #check variables before execution

    my $problems = 0;
    foreach my $n (@{$self->{'nodes'}}){
        $problems-- unless $n->ping;
        $problems-- unless $n->isReachable;
    }
    INFO "Configuration check completed";
    return $problems;
}

sub getNodesInfo{
    my $self = shift;
    foreach my $n (@{$self->{'nodes'}}){
        $n->getConfig;
    }
    INFO "Configuration configuration harvest completed";

}

#yaml/descriptor functions

sub getOSSs{
    my $self = shift;
    return grep { $_->{'type'} eq 'oss' } @{$self->cfg->{'LustreObjects'}};
}

sub getMDSs{
    my $self = shift;
    return grep { $_->{'type'} eq 'mds' } @{$self->cfg->{'LustreObjects'}};
}

sub getClients{
    my $self = shift;
    my @clients;
    #print Dumper $self->cfg;
    foreach my $lo (@{$self->cfg->{'LustreObjects'}}){
        if( $lo->{'type'} eq 'client'){
           push @clients, $lo;
        }
    }
    return \@clients;

}

sub getMasterClient{
    my $self = shift;
    foreach my $lo (@{$self->cfg->{'LustreObjects'}}){
        if(( $lo->{'type'} eq 'client')
                &&( $lo->{'master'} eq 'yes')){
           return $lo;
        }
    }
    return undef;
}

=over 12

=item * B<getLustreNodeAddress> - retrun lustre ip address(B<lustreip>) if 
defined or common ip.  See also B<getNodeAddress>

=back

=cut

sub getLustreNodeAddress{
    my ($self, $id) = @_;
    foreach my $n (@{$self->nodes}){
        return $n->lustreip 
            if(($n->id eq $id)and
                (defined($n->lustreip)));
        return $n->ip    if( $n->id eq $id);
    }
    return undef;
}

=over 12

=item * B<getNodeAddress> - return common ip address which must be defined for node.

=back

=cut

sub getNodeAddress{
    my ($self, $id) = @_;
    foreach my $n (@{$self->nodes}){
        return $n->ip    if( $n->id eq $id);
    }
    return undef;
}

sub getNodeUser{
    my ($self, $id) = @_;
    foreach my $n (@{$self->nodes}){
        return $n->user    if( $n->id eq $id);
    }
    return undef;
}

sub getNodeById{
    my ($self, $id) = @_;
    foreach my $n (@{$self->nodes}){
        return $n    if( $n->id eq $id);
    }
    return undef;

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

