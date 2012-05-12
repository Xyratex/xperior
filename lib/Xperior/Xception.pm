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

package Xperior::Xception;

use base qw(Error);
use overload ( '""' => 'stringify' );

sub new {
    my $self = shift;
    my $text = "" . shift;
    my @args = ();

    local $Error::Depth = $Error::Depth + 1;
    local $Error::Debug = 1; # Enables storing of stacktrace

    $self->SUPER::new( -text => $text, @args );
}
1;

package NoSchemaException;
use base qw(Xperior::Xception);
1;

package CannotPassSchemaException;
use base qw(Xperior::Xception
        );
1;

