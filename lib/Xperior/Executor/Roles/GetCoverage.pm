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
                " lcov --zerocounters ", 60 );
        last;
    }

};


after   'execute' => sub{
    my $self    = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById($nid->{'node'});
        my $c = $n->getExclusiveRC;

        DEBUG $c->createSync(
                 " lcov --no-checksum --ignore-errors source "
                ." -b /root/cov/lustre-wc-rel/ "#fixed lustre paths
                ." --capture --output-file /tmp/coverage.$n->{id} 2&>1 > /dev/null ",
                300 );
       my  $syncres = $c->syncexitcode;
        if ($syncres != 0){
            DEBUG "Cannot collect kernel lcov data, exit code is [$syncres]";
            exit 99;
        }

        DEBUG `rm -rf "/tmp/coverage.$n->{id}"`;
        my $res = $c->getFile( "/tmp/coverage.$n->{id}","/tmp/coverage.$n->{id}");

        my $cmd = 
                "perl ".$ENV{'WORKSPACE'}."/scripts/coverage/lcov_filter.pl "
                ." -s /tmp/coverage.$n->{id} "
                ." -o ".$self->getNormalizedLogName('coverage.'.$n->id)
                ." -p 'lnet'  -p 'libcfs' -p 'lustre-wc-rel.lustre'  ";
        DEBUG `$cmd`;

        
        if ($res == 0){
            $self->registerLogFile('coverage.'.$n->id,
                $self->getNormalizedLogName('coverage.'.$n->id));
        }else{
            $self->addMessage(
                "Cannot attach coverage file log [coverage.$n->{id}]: $res");
        }

        DEBUG $c->createSync(
                 "lcov --no-checksum "
                #."-b /root/cov/lustre-wc-rel/ "#fixed lustre paths
                ." -d /root/cov/lustre-wc-rel/ "
                ." -k /lib/modules/2.6.32/build/ " #fixed kernel
                #."--remove fullcoverage.trace '*kernel*' "
                ." --capture --output-file /tmp/usercoverage.$n->{id} 2&>1 > /dev/null ",
                300 );
        $syncres = $c->syncexitcode;
        if ($syncres != 0){
            DEBUG "Cannot collect user lcov data, exit code is [$syncres]";
            exit 99;
        }

        $res = $c->getFile( "/tmp/usercoverage.$n->{id}",
            $self->getNormalizedLogName('usercoverage.'.$n->id));
        if ($res == 0){
            $self->registerLogFile('usercoverage.'.$n->id,
                $self->getNormalizedLogName('usercoverage.'.$n->id));
        }else{
            $self->addMessage(
                "Cannot attach coverage file log [usercoverage.$n->{id}]: $res");

        }

        last;
    }
};


1;


