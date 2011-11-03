#
#===============================================================================
#
#         FILE:  MDTest.pm
#
#  DESCRIPTION:  Module which contains MDTest specific execution functionality. 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex 
#      CREATED:  11/01/2011 
#===============================================================================
=pod
=head1 DESCRIPTION

B<mdtest> wrapper module for XTests harness. Pretty same to IOR wrapper,
in future must be one class for both tests.

=cut

package XTests::Executor::MDTest;
use Moose;

extends 'XTests::Executor::OpenMPIBase';

after 'init' => sub{
    my $self    = shift;
    $self->appname('mdtest');
    $self->cmdfield('mdtestcmd');
    $self->reset;
};

__PACKAGE__->meta->make_immutable;

1;
