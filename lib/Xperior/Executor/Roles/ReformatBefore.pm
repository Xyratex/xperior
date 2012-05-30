#
#===============================================================================
#
#         FILE:  Xperior/Executor/Roles/ReformatBefore.pm
#
#  DESCRIPTION:  Role define reformating fs before every test. Only
#                one-node configuration supported now.
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  05/05/2012
#===============================================================================

package Xperior::Executor::Roles::ReformatBefore;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
use Data::Dumper;

requires 'env';

before 'execute' => sub {
    my $self = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById($nid->{'node'});
        my $c = $n->getExclusiveRC;
        DEBUG $c->createSync( " sh /usr/lib64/lustre/tests/llmountcleanup.sh", 300 );
        DEBUG $c->createSync( " FORMAT=yes sh /usr/lib64/lustre/tests/llmount.sh", 300 );
        last;
    }

};

1;
