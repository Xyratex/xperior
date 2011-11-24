#
#===============================================================================
#
#         FILE:  XTest::Node.pm
#
#  DESCRIPTION:  Node  abstraction. Allows to get info about node. 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex 
#      CREATED:  08/31/2011 10:38:28 AM
#===============================================================================

=pod

=head1 Class implements different functions to work with node and get information about them.



=cut

package XTests::Node;

use Moose;
use Moose::Util::TypeConstraints;

#use Test::Net::Service;
use Net::Ping;
use Log::Log4perl qw(:easy);

use XTests::SshProcess;

has 'ctrlproto'    => ( is => 'rw' );
has 'user'         => ( is => 'rw' );
has 'pass'         => ( is => 'rw' );
has 'ip'           => ( is => 'rw' );
has 'id'           => ( is => 'rw' );

has 'rconnector'   => (
                        is => 'rw',
                        default => undef);

=over *

=item isReachable

check that node is reachable via ssh (pdsh - TBI), and Lustre basic liveness (Lustre is up and files can be created).  

=back

=cut

sub isReachable{
    my $self = shift;
    #TODO only ssh now is supported
    my $sc =$self->_getRemoteConnector;
    unless ( defined ($sc)){
        die "Cannot ssh host [".$self->id."]";
    }else{
        DEBUG $self->id ." is reachable ";
    }
}

=over *

=item ping

check that node is reachable via ping

=back

=cut


sub ping {
    my $self = shift;
    my $p = Net::Ping->new();
    INFO "PING host ".$self->{'ip'};
    if ($p->ping($self->{'ip'})){
        INFO "host is alive.\n";
        return 1;
    }else{
        ERROR "host is unreachable.\n";
        return 0;
    }
}

sub getNodeConfiguration{

}

sub getLFFreeSpace{
    my $self = shift;
    my $sc =$self->_getRemoteConnector;
    my $cmd = $sc->createSync("lfs df");
    foreach my $str ( split(/\n/,$cmd)){
        return $1 
            if( $str =~ m/filesystem\ssummary\:\s+\d+\s+\d+\s+(\d+)/ );
    }
    DEBUG "getLFFreeSpace -  cannot parse:[$cmd]";
    return -1;
}

sub getLFFreeInodes{
    my $self = shift;
    my $sc =$self->_getRemoteConnector;
    my $cmd = $sc->createSync("lfs df -i");
    foreach my $str ( split(/\n/,$cmd)){
        return $1 
            if( $str =~ m/filesystem\ssummary\:\s+\d+\s+\d+\s+(\d+)/ );
    }
    DEBUG "getLFFreeInodes -  cannot parse:[$cmd]";
    return -1;
}

sub getLFCapacity{
    my $self = shift;
    my $sc =$self->_getRemoteConnector;
    my $cmd = $sc->createSync("lfs df");
    foreach my $str ( split(/\n/,$cmd)){
        return $1 
            if( $str =~ m/filesystem\ssummary\:\s+(\d+)\s+\d+\s+\d+/ );
    }
    DEBUG "getLFCapacity -  cannot parse:[$cmd]";
    return -1;

}

sub _getRemoteConnector{
    my $self = shift;
    return $self->rconnector 
         if defined $self->rconnector;
    
    my $sc = XTests::SshProcess->new();
    
    if ($sc->init($self->ip,$self->user) < 0){
        $self->rconnector(undef);
        return undef;
    }

    $self->rconnector($sc);
    return $sc;
}

__PACKAGE__->meta->make_immutable;
