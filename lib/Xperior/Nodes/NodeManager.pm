#
#===============================================================================
#
#         FILE: NodeManager.pm
#
#  DESCRIPTION: 
#
#       AUTHOR: ryg,kyr
# ORGANIZATION: Xyratex
#      VERSION: 1.0
#      CREATED: 06/29/2012 05:51:49 PM
#===============================================================================

=pod

=head1 Base class for different nodes support.

Abstract class implements simple functionality for check node start and provide method list which must be implemented in inheritors.  



=cut



package Xperior::Nodes::NodeManager; 

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Net::Ping;

use Moose::Role;

=over 4

=item halt

Shutdown and/or power off remote host. Asynchronous operation.

=item start

Boot and/or power on remote host. Asynchronous operation.

=item isAlive

Check that system is alive by control system. Doesn't mean that node is available by network.

=item sync

Wait some time to be sure that action (start, halt) is processed by control system.

=cut

requires qw(halt start restoreSystem isAlive sync); 
has 'ssh'       => ( is => 'rw', isa => 'Xperior::SshProcess');
has 'host'   => ( is => 'ro', isa => 'Str' ); #dns or ip

has '_pinger' => (is => 'rw', isa => 'Net::Ping');

=over *

=item waitUp($timeout)

Wait until node up (available via ssh) and set ssh member, return 1.
If node is not up until $timeout or ssh connection failed return 0.

=back

=cut

sub waitUp {
    my ($self, $timeout) = @_;
    $self->{ssh} = $self->_waitForNodeUp( $self->host, $timeout );
    return defined $self->{ssh};
}

=over *

=item ping

Ping node.

=back

=cut

sub ping {
 my $self = shift;
 $self->_pinger(Net::Ping->new()) unless defined $self->_pinger;
 return $self->_pinger->ping($self->host);
}

sub _waitForNodeUp {
    my ($self, $node, $timeout ) = @_;
    my $sp;
    my $st = time;
    my $up = 0;
    my $starttime = time;
    my $p = Net::Ping->new();
    INFO "Wait until $node up";

    while ( ( $st + $timeout ) > time ) {
        if ( $self->ping ) {
            INFO "host is alive, check ssh\n";

#DEBUG `ssh -v  -o 'BatchMode yes' -o 'AddressFamily inet'  -f root\@mft03 'uname -a'`;
            $sp = Xperior::SshProcess->new();
            my $ss = $sp->init( $node, 'root', 22, 1 );
            if ( $ss == 0 ) {
                INFO "ssh is up\n";
                $up = 1;
                last;
            }
            else {
                ERROR "ssh is down,wait.\n";
            }
        }
        else {
            ERROR "host is unreachable,wait.\n";
        }
        sleep 15;
    }
    unless ($up) {
        WARN "VM is not up in [".(time - $starttime)."] sec";
        return undef;
    }
    return $sp;
}


1;
