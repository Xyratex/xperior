#
#===============================================================================
#
#         FILE:  XTest/Executor/Roles/LustreClientStatus.pm
#
#  DESCRIPTION:  Role define harvesting info from master client host 
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  12/20/2011 09:45:19 PM
#===============================================================================

package XTest::Executor::Roles::LustreClientStatus;

use Moose::Role;

requires 'env';

before 'execute' => sub{
    my $self    = shift;
    $self->_saveStageInfo('before');

};


after   'execute' => sub{
    my $self    = shift;
    $self->_saveStageInfo('after');
};


sub _saveStageInfo{
    my ($self,$item) = @_;
    my %info;
    my $mc = $self->env->getNodeById
        ($self->env->getMasterClient->{'node'});
    $info{'lfs_freespace'}  = $mc->getLFFreeSpace;
    $info{'lfs_freeinodes'} = $mc->getLFFreeInodes; 
    $info{'lfs_capacity'}   = $mc->getLFCapacity;
    $self->addYE($item."_execution",\%info);
}




#__PACKAGE__->meta->make_immutable;
1;
