#
#===============================================================================
#
#         FILE: BasicNode.pm
#
#  DESCRIPTION: The simpliest nodemanager which doesn't support any feature exclude ssh connection 
#
#       AUTHOR: ryg 
# ORGANIZATION: Xyratex
#      CREATED: 07/06/2012 11:59:24 PM
#===============================================================================
package Xperior::Nodes::BasicNode;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Carp;
use Error qw(try finally except otherwise);
use Xperior::SshProcess;
use Xperior::Utils;
use Xperior::Xception;
use Moose::Role;
with qw( Xperior::Nodes::NodeManager );

sub sync{
    throw MethodNotImplementedException("sync is not implemented because it is basic implementation");
}

sub isAlive {
    throw MethodNotImplementedException "isAlive is not implemented because it is basic implementation";
}


sub halt {
    throw MethodNotImplementedException "halt is not implemented because it is basic implementation";
}

sub start {
    throw MethodNotImplementedException "start is not implemented because it is basic implementation";
}

sub restoreSystem {
    throw MethodNotImplementedException "restoreSystem is not implemented because it is basic implementation";
}
1;
