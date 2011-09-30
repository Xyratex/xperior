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

#This could gather cluster config data, disk sizes, space available, network type, cpu count, that nodes are reachable via ssh/pdsh, and Lustre basic liveness (Lustre is up and files can be created).
has 'nodes'      => ( is => 'rw',isa => 'ArrayRef[]', );
sub init{
    my $self = shift;
    my $yamlcfg = shift;
    foreach my $n (@{$yamlcfg->{'Nodes'}}){
        my $node = XTests::Node->new;
        $node->{'id'} = $n->{'id'};
        $node->{'ip'} = $n->{'ip'};
        $node->{'ctrlproto'} = $n->{'ctrlproto'};
        $node->{'user'} = $n->{'user'};
        $node->{'pass'} = $n->{'pass'};
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

sub getLusterConfig{

}

sub getDiskSizes{
}

sub getFreeSpace{

}

sub getNetworkType{
}


__PACKAGE__->meta->make_immutable;
