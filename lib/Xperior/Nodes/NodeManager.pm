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

has 'nodedescriptor' => ( is => 'rw', isa => 'Str');
has 'console'        => ( is => 'rw');

=over 5

=item halt

Shutdown and/or power off remote host. Asynchronous operation.

=item start

Boot and/or power on remote host. Asynchronous operation.

=item isAlive

Check that system is alive by control system. Doesn't mean that node is available by network.

=item sync

Wait some time to be sure that action (start, halt) is processed by control system.

=item restoreSystem

restore OS state to orignal state and reboot

=cut

requires qw(halt start restoreSystem isAlive sync); 
#has 'host'   => ( is => 'ro', isa => 'Str' ); #dns or ip

1;

