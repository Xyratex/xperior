#
#===============================================================================
#
#         FILE:  XTests::TestEnvironment.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  08/30/2011 11:59:25 PM
#     REVISION:  ---
#===============================================================================

package XTests::TestEnvironment;

use Moose;
use XTests::Node;
use Log::Log4perl qw(:easy);
use Carp;
use Data::Dumper;

#This could gather cluster config data, disk sizes, space available, network type, cpu count, that nodes are reachable via ssh/pdsh, and Lustre basic liveness (Lustre is up and files can be created).
has 'nodes'      => ( is => 'rw',isa => 'ArrayRef[]', );
has 'cfg'    => ( is => 'rw');
sub init{
    my $self = shift;
    my $yamlcfg = shift;
    $self->cfg($yamlcfg);
    foreach my $n (@{$yamlcfg->{'Nodes'}}){
        my $node = XTests::Node->new;
        $node->id($n->{'id'});
        $node->ip($n->{'ip'});
        $node->ctrlproto( $n->{'ctrlproto'});
        $node->user( $n->{'user'});
        $node->pass($n->{'pass'});
        push @{$self->{'nodes'}},$node;
    }
}

sub checkEnv{
    DEBUG "Start env check";
    my $self = shift;
    foreach my $n (@{$self->{'nodes'}}){
        #$n->ping;
        #$n->isReachable;
    }
    INFO "Configuration check completed";
}

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

sub getLusterConfig{

}

sub getDiskSizes{
}

sub getFreeSpace{

}

sub getNetworkType{
}


__PACKAGE__->meta->make_immutable;
