#
#===============================================================================
#
#         FILE:  GetCoverage.pm
#
#  DESCRIPTION:  Role define coverage storing via lcov. Special calls are done before and after test execution. Only one-node cluster supported.
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  05/23/2012 03:34:15 PM
#===============================================================================
package Xperior::Executor::Roles::GetCoverage;

use strict;
use warnings;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
use Data::Dumper;

requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

before 'execute' => sub {
    my $self = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById($nid->{'node'});
        DEBUG "Target node:".$n->ip;
        my $c = $n->getExclusiveRC;
        DEBUG $c->createSync( 
                " mount -t debugfs none /sys/kernel/debug", 60 );
        
        DEBUG $c->createSync( 
                " lcov --zerocounters", 60 );
        last;
    }

};


after   'execute' => sub{
    my $self    = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById($nid->{'node'});
        my $c = $n->getExclusiveRC;

        DEBUG $c->createSync(
                "lcov --no-checksum "
                ."-b /root/cov/lustre-wc-rel/ "#fixed lustre paths
                ."-d /root/cov/lustre-wc-rel/ "
                #."-b /lib/modules/2.6.32/build/ " #fixed kernel
                #."--remove fullcoverage.trace '*kernel*' "
                ."--capture --output-file /tmp/coverage.$n->{id} ",
                300 );
            my $res = $c->getFile( "/tmp/coverage.$n->{id}",
            $self->getNormalizedLogName('coverage.'.$n->id));
            if ($res == 0){
                $self->registerLogFile('coverage.'.$n->id,
                     $self->getNormalizedLogName('coverage.'.$n->id));
            }else{
                $self->addMessage(
                    "Cannot attach coverage file log [coverage.$n->{id}]: $res");

            }
            
        last;
    }
};


1;


