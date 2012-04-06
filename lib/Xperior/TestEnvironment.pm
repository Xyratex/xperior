#
#===============================================================================
#
#         FILE:  Xperior/TestEnvironment.pm
#
#  DESCRIPTION:  This class maintains test environment and configuration.
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex 
#      CREATED:  08/30/2011 11:59:25 PM
#===============================================================================

=pod 

=head1 Class maintains test environment and configuration.

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

sub init{
    my $self = shift;
    my $yamlcfg = shift;
    $self->cfg($yamlcfg);
    foreach my $n (@{$yamlcfg->{'Nodes'}}){
        my $node = Xperior::Node->new;
        $node->id($n->{'id'});
        $node->ip($n->{'ip'});
        $node->ctrlproto( $n->{'ctrlproto'});
        $node->user( $n->{'user'});
        $node->pass($n->{'pass'});
        if(defined($n->{'console'})){
            $node->console($n->{'console'});
        }else{
            $node->console(undef);
        }
        push @{$self->{'nodes'}},$node;
    }
}

sub checkEnv{
    DEBUG "Start env check";
    my $self = shift;

    #TODO
    #check variables there
    my $problems = 0;
    foreach my $n (@{$self->{'nodes'}}){
        #TOD enable it for future
        $problems-- unless $n->ping;
        $problems-- unless $n->isReachable;
    }    
    INFO "Configuration check completed";
    return $problems;
}

sub getNodesInfo{
    my $self = shift;
    foreach my $n (@{$self->{'nodes'}}){
        $n->getNodeConfiguration;
    }    
    INFO "Configuration configuration harvest completed";

}

#yaml/descriptor functions

sub getOSSs{
    my $self = shift;
    my @osss;
    #print Dumper $self->cfg;
    foreach my $lo (@{$self->cfg->{'LustreObjects'}}){
        if( $lo->{'type'} eq 'oss'){
           push @osss, $lo;              
        }
    }    
    return \@osss;
}

sub getMDSs{
    my $self = shift;
    my @mdss;
    #print Dumper $self->cfg;
    foreach my $lo (@{$self->cfg->{'LustreObjects'}}){
        if( $lo->{'type'} eq 'mds'){
           push @mdss, $lo;              
        }
    }    
    return \@mdss;

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


#object functions

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

=begin  BlockComment  # BlockCommentNo_1


sub getLusterConfig{

}

sub getDiskSize{
}

sub getFreeSpace{

}

sub getNetworkType{
}

=end    BlockComment  # BlockCommentNo_1

=cut



__PACKAGE__->meta->make_immutable;
