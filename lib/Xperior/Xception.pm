#
#===============================================================================
#
#         FILE:  Xception.pm
#
#  DESCRIPTION:  Xperior exceptions
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  05/07/2012 03:44:02 PM
#===============================================================================

=pod

=head1 Xperior exceptions

these execption should be used for customizing error processing

=cut

package Xperior::Xception;

use overload ( '""' => 'stringify' );
#use Carp qw(cluck);
use base qw(Error);

sub new {
    my $self = shift;
    my $text = "" . shift;
    my @args = ();

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1;                   # Enables storing of stacktrace

    $self->SUPER::new( -text => $text, @args );

    #cluck "Exception generated";
}

1;

package NoSchemaException;
use base qw(Xperior::Xception);
1;

package CannotPassSchemaException;
use base qw(Xperior::Xception);
1;

package KVMException;
use base qw(Xperior::Xception);
1;

package NullObjectException;
use base qw(Xperior::Xception);
1;

package CannotConnectException;
use base qw(Xperior::Xception);
1;

package MethodNotImplementedException;
use base qw(Xperior::Xception);
1;



