#
#===============================================================================
#
#         FILE:  GetCoverage.pm
#
#  DESCRIPTION:  Role define coverage storing via lcov. Special calls are done
#  before and after test execution. Only one-node cluster supported. Lock on
#  well-know environment.
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

requires 'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile', '_reportDir';

use constant LDIR => '/root/cov/lustre-wc-rel/';

before 'execute' => sub {
    my $self = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById( $nid->{'node'} );
        DEBUG "Target node:" . $n->ip;
        my $c = $n->getExclusiveRC;
        DEBUG $c->createSync( " mount -t debugfs none /sys/kernel/debug", 60 );
        DEBUG $c->createSync( " lcov --zerocounters ",                    60 );

        #this is hack and bad way
        #only because coverage collection is pretty specific work
        #this code is written

        #create dir is not exits
        $self->getNormalizedLogName('coverage.'.$n->{id});
        
        #manually  constrcut resource name
        my $initcov =  
           $self->_reportDir.
           "/init.coverage.$n->{id}.log"; 

        my $initusercov =  
           $self->_reportDir.
           "/init.usercoverage.$n->{id}.log"; 

        #generate init info only one per session
        unless ( -e $initcov ) {
            $self->getCoverage( $c, $n->{id}, $initcov , $initusercov,' --initial ' );
        }
        else {
            DEBUG "Init coverage file [$initcov] exists";
        }
        last;
    }

};

after 'execute' => sub {
    my $self = shift;
    foreach my $nid ( @{ $self->env->getMDSs } ) {
        my $n = $self->env->getNodeById( $nid->{'node'} );
        my $c = $n->getExclusiveRC;

        $self->getCoverage( 
                $c, $n->{id}, 
                $self->getNormalizedLogName( 'coverage.' . $n->{id} ),
                $self->getNormalizedLogName( 'usercoverage.' . $n->{id} ),        
                '' );
        last;
    }
};

sub getCoverage {
    my ( $self, $ssh, $node, $logcov, $logusercov,  $moreparams ) = @_;
    DEBUG "Collect coverage for test [$node]";
    #workaround of lcov bug. sometimes gcda filea stops code covrage
    DEBUG $ssh->createSync(
'find /root/cov -name \\"*.gcda\\"  -type l   -exec rm -f -v \\"{}\\" \\\;',
        120
    );

    DEBUG $ssh->createSync(
        " lcov $moreparams --no-checksum --ignore-errors source " . " -b "
          . LDIR . " "
          . " --capture --output-file /tmp/coverage.$node  1>/dev/null 2>&1 ",
        300
    );
    my $syncres = $ssh->exitcode;
    if ( $syncres != 0 ) {
        DEBUG "Cannot collect kernel lcov data, exit code is [$syncres]";
        exit 99;
    }

    DEBUG `rm -rf "/tmp/coverage.$node"`;
    my $res = $ssh->getFile( "/tmp/coverage.$node", "/tmp/coverage.$node" );

    if ( $res == 0 ) {
        filter( "/tmp/coverage.$node",$logcov);
        if( $moreparams =~ m/--initial/ ){
            WARN "[$logcov] is not attached to test result";
        }else{
            $self->registerLogFile( 'coverage.' . $node, $logcov );
            
        }
    }
    else {
        $self->addMessage(
            "Cannot attach coverage file log [coverage.$node]: $res");
    }

    DEBUG $ssh->createSync(
        "lcov $moreparams --no-checksum "

          #."-b /root/cov/lustre-wc-rel/ "#fixed lustre paths
          . " -d " . LDIR . " "
          . " -k /lib/modules/2.6.32/build/ "    #fixed kernel
              #."--remove fullcoverage.trace '*kernel*' "
          . " --capture --output-file /tmp/usercoverage.$node -q ",
        300
    );
    $syncres = $ssh->exitcode;
    if ( $syncres != 0 ) {
        DEBUG "Cannot collect user lcov data, exit code is [$syncres]";
        exit 99;
    }

    $res =
      $ssh->getFile( "/tmp/usercoverage.$node",
                            "/tmp/usercoverage.$node");
    if ( $res == 0 ) {
        filter( "/tmp/usercoverage.$node",$logusercov);
        if( $moreparams =~ m/--initial/ ){
            WARN "[$logusercov] is not attached to test result";
        }else{
            $self->registerLogFile( 'usercoverage.' . $node, $logusercov );
        }
    }
    else {
        $self->addMessage(
            "Cannot attach coverage file log [usercoverage.$node]: $res" );

    }

}

sub filter {
    my ($inputfile, $outputfile)= @_;
    my $cmd = "perl "
      #use Jenkins env var
      . $ENV{'WORKSPACE'}
      . "/scripts/coverage/lcov_filter.pl "
      . " -s $inputfile  -o $outputfile "
      . " -p 'lnet'  -p 'libcfs' -p 'lustre-wc-rel.lustre'  ";
    DEBUG "Executing $cmd";
    DEBUG `$cmd`;    
    return 1;
} ## --- end sub filter
1;

