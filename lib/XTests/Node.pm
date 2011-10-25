#
#===============================================================================
#
#         FILE:  XTest::Node.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  08/31/2011 10:38:28 AM
#     REVISION:  ---
#===============================================================================

package XTests::Node;

use Moose;
#use Test::Net::Service;
use Net::Ping;
use Log::Log4perl qw(:easy);

has 'ctrlproto'    => ( is => 'rw' );
has 'user'         => ( is => 'rw' );
has 'pass'         => ( is => 'rw' );
has 'ip'           => ( is => 'rw' );
has 'id'           => ( is => 'rw' );


#that nodes are reachable via ssh/pdsh, and Lustre basic liveness (Lustre is up and files can be created).  

sub isReachable{
    my $self = shift;
    #TODO only ssh now is supported
=item *
    my $host = $self->{'ip'};
    my $net_service = Test::Net::Service->new(
                'host'  => $host,
                'proto' => 'tcp',
     );
     my $res = $net_service->connect(
                        'port'    => 22,
                        'service' => 'ssh',
                );
     $res = $net_service->test_ssh(
                        'port'    => 22,
                        'service' => 'ssh',
                );


    DEBUG "SSH check for [$host]:$res";
=cut
}

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

sub checkSSH{

}

sub getNodeConfiguration{

}

__PACKAGE__->meta->make_immutable;
