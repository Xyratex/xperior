#
#===============================================================================
#
#         FILE:  GetDiagnostics.pm
#
#  DESCRIPTION:  Call lustre-diagnostic on every node and get xml results
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  02/10/2012 03:55:40 PM
#===============================================================================

=pod

=head1 NAME

Xperior::Executor::Roles::GetDiagnostics - gathering information on node after test failure

=head1  DESCRIPTION

The module contains function which called after every execution for harvest diagnostic information from nodes which defined in configuration.

The module requests setup of lustre-diagnostic package on every node in cluster.

Result of the module is file C<(testid).diagnostic.xml.(node id>.log>

For enable this module for test or test group add to C<roles> property string C<GetDiagnostics>  

=cut

package Xperior::Executor::Roles::GetDiagnostics;

use strict;
use warnings;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;

requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

after 'execute' => sub {
    my $self = shift;
  if ( ( $self->yaml->{status_code} ) == 1 ) {    #test failed
   foreach my $n (@{$self->env->nodes}){
        my $c = $n->getExclusiveRC;
        my $td = '/tmp/xpdiagnostic.'
                    .Time::HiRes::gettimeofday().'.xml';
        
        $c->createSync("/usr/sbin/lustre-diagnostics -x $td",300);

        my $res = $c->getFile( $td,
            $self->getNormalizedLogName('diagnostic.xml.'.$n->id));
            if ($res == 0){
                $self->registerLogFile('diagnostic.xml.'.$n->id,
                     $self->getNormalizedLogName
                                ('diagnostic.xml.'.$n->id));
            }else{
                $self->addMessage(
                    "Cannot copy log file [$td]: $res");

            }
        

        }
   }

};

1;
