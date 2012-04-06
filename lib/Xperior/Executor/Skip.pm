#
#===============================================================================
#
#         FILE:  Skip.pm
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  02/06/2012
#===============================================================================
package Xperior::Executor::Skip;
use Moose;
extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = '0.01';


sub execute{
    my $self = shift;
    my $id = $self->test->getParam('id');
    $self->skip('2','Excluded by exclude list');
    $self->test->results ($self->yaml);
}

1;


