#
#===============================================================================
#
#         FILE:  IOR.pm
#
#  DESCRIPTION:  Module which contains IOR specific execution functionality. 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex 
#      VERSION:  1.1
#      CREATED:  10/08/2011 
#===============================================================================
=pod
=head1 DESCRIPTION

IOR wrapper module for XTests harness.

=cut

package XTests::Executor::IOR;
use Moose;

extends 'XTests::Executor::OpenMPIBase';


after 'init' => sub{
    my $self    = shift;
    $self->appname('IOR');
    $self->cmdfield('iorcmd');
    $self->reset;
};


__PACKAGE__->meta->make_immutable;

1;
