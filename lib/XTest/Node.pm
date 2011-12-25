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

package XTest::Node;

use Moose;
use Moose::Util::TypeConstraints;

use Net::Ping;
use Log::Log4perl qw(:easy);

use XTest::Utils;
use XTest::SshProcess;

has 'ctrlproto'    => ( is => 'rw' );
has 'user'         => ( is => 'rw' );
has 'pass'         => ( is => 'rw' );
has 'ip'           => ( is => 'rw' );
has 'id'           => ( is => 'rw' );
has 'console'      => ( is => 'rw' );

has 'architecture'    => ( is => 'rw');
has 'os'              => ( is => 'rw');
has 'os_release'      => ( is => 'rw');
has 'os_distribution' => ( is => 'rw');
has 'lustre_version'  => ( is => 'rw');
has 'lustre_net'      => ( is => 'rw');

has 'memtotal'        => ( is => 'rw');
has 'memfree'         => ( is => 'rw');
has 'swaptotal'       => ( is => 'rw');
has 'swapfree'        => ( is => 'rw');

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
    my $sc;
    eval{
        $sc=$self->getRemoteConnector;
    };
    if( $@){
         WARN "Cannot connec to host".$@;
         return 0;
    }
    unless ( defined ($sc)){
        WARN "Cannot ssh host [".$self->id."]";
        return 0;
    }else{
        DEBUG $self->id ." is reachable ";
        return 1;
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
    my $self = shift;
    my $sc = $self->getRemoteConnector;
    $self->architecture(trim($sc->createSync('uname -m')));
    $self->os(trim($sc->createSync('uname -o')));
    $self->os_release( 
            trim( 
                (split(':\s',$sc->createSync('lsb_release -r')))
                [1]
                ));

    $self->os_distribution( 
            trim(
                (split(':\s',$sc->createSync('lsb_release -d')))
                [1]
                ));

    $self->lustre_version( 
            trim(
                (split('\s', $sc->createSync('lctl lustre_build_version')))
                    [2] ));
    $self->lustre_net( 
            trim(
                (split('@', $sc->createSync('lctl list_nids ')))
                    [1] ));

    my $memout = $sc->createSync('cat /proc/meminfo');
    foreach my $s ( split('\n',$memout)){
        if( $s =~ m/MemTotal:\s+(\d+)/){
            $self->memtotal($1);
        }
        if( $s =~ m/MemFree:\s+(\d+)/){
            $self->memfree($1);
        }
        if( $s =~ m/SwapTotal:\s+(\d+)/){
            $self->swaptotal($1);
        }
        if( $s =~ m/SwapFree:\s+(\d+)/){
            $self->swapfree($1);
        }
    }

    #TODO add CPU processor count
    #my $cpuout = $sc->createSync('cat /proc/cpuinfo');
}

sub getLFFreeSpace{
    my $self = shift;
    my $sc =$self->getRemoteConnector;
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
    my $sc =$self->getRemoteConnector;
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
    my $sc =$self->getRemoteConnector;
    my $cmd = $sc->createSync("lfs df");
    foreach my $str ( split(/\n/,$cmd)){
        return $1 
            if( $str =~ m/filesystem\ssummary\:\s+(\d+)\s+\d+\s+\d+/ );
    }
    DEBUG "getLFCapacity -  cannot parse:[$cmd]";
    return -1;

}

=over *

=item getRemoteConnector

Return connector for node. This connector is the main node connector and should be used for short (synchronous) execution and main single execution for avoid memory wasting. If consumer need more then one long a synchronous execution next connector can be get via connector clone or via getUncontrolledRC

=back

=cut

sub getRemoteConnector{
    my $self = shift;
    return $self->rconnector 
         if defined $self->rconnector;
    
    my $sc = XTest::SshProcess->new();
    
    if ($sc->init($self->ip,$self->user) < 0){
        $self->rconnector(undef);
        return undef;
    }

    $self->rconnector($sc);
    return $sc;
}

=over *

=item getExclusiveRC

Return a connector which can be used exclusively by consumer. Nobody more can get it.

=back

=cut



sub getExclusiveRC{
    my $self = shift;
    my $rc = $self->getRemoteConnector;
    my $urc = undef;
    if( defined ( $rc)){
        $urc = $rc->clone;
    }
    return $urc; 
}
__PACKAGE__->meta->make_immutable;
