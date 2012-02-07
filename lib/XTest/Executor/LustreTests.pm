#
#===============================================================================
#
#         FILE:  LustreTests.pm
#
#  DESCRIPTION: Module which contains Lustre execution specific functionality
#
#       AUTHOR:  ryg
#      COMPANY:  Xyratex
#      CREATED:  09/27/2011 11:47:51 PM
#===============================================================================
package XTest::Executor::LustreTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);

extends 'XTest::Executor::SingleProcessBase';

our $VERSION = "0.0.2";

has 'mdsopt'  => ( is => 'rw' );
has 'ossopt'  => ( is => 'rw' );
has 'clntopt' => ( is => 'rw' );
has 'reason'  => ( is => 'rw' );

after 'init' => sub {
    my $self = shift;
    $self->appname('sanity');

    #$self->reset;
    $self->reason('');
};

sub getReason {
    my $self = shift;
    return $self->reason;
}

sub _prepareCommands {
    my $self = shift;
    $self->_prepareEnvOpts;
    my $td  = '';
    my $ext = '.sh';
    $td = $self->env->cfg->{'tempdir'} if defined $self->env->cfg->{'tempdir'};
    my $dir    = $self->env->cfg->{'client_mount_point'} . $td;
    my $tid    = 'ONLY=' . $self->test->testcfg->{id};
    my $script = $self->test->getParam('groupname');
    if ( defined( $self->test->getParam('script') ) ) {
        $script = $self->test->getParam('script');
        $tid    = '';                                #no default test number
        $ext = '';    #ext must be set also when script is set
    }

    #REFORMAT=YES
    $self->cmd( "SLOW=YES  "
          . $self->mdsopt . " "
          . $self->ossopt . " "
          . $self->clntopt
          . " $tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -S -w \\\" /usr/lib64/lustre/tests/${script}${ext}"
    );

#    $self->cmd("SLOW=YES  ".$self->mdsopt." ".$self->ossopt." ".$self->clntopt." ONLY=$tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -S -w \\\"  ACC_SM_ONLY=${script} /usr/lib64/lustre/tests/acceptance-small.sh");

}

# 0   - passed
# 1   - skipped
# 10  - failed
# 100 - no result set, failed too
sub processLogs {
    my ( $self, $file ) = @_;
    DEBUG("Processing log file [$file]");
    open( F, "  $file" );

    my $passed = 100;
    my $reason = '';
    my @results;
    #consider only last keywords! 
    while ( defined( my $s = <F> ) ) {
        chomp $s;
        if ( $s =~ m/PASS/ ) {
            $passed = 0;
        }
        if ( $s =~ m/FAIL:(.*)/ ) {
            $passed = 10;
            $reason = $1;
        }
        if ( $s =~ /SKIP:(.*)/ ) {
            $passed = 1;
            $reason = $1;
        }
        #don't see next messages after test end 
        #================== 05:28:17
        if ( $s =~ /test\s+complete.*=+\s+\d\d:\d\d:\d\d\s+/){
            last;
        }
    }
    unless ($passed) {
        $self->reason($reason);
    }
    close(F);
    return $passed;
}

sub _prepareEnvOpts {
    my $self    = shift;
    my $mdss    = $self->env->getMDSs;
    my $osss    = $self->env->getOSSs;
    my $clietns = $self->env->getClients;
    $self->mdsopt('');
    my $c = 1;
    foreach my $m (@$mdss) {
        $self->mdsopt( $self->mdsopt
              . " MDSDEV$c="
              . $m->{'device'}
              . " mds${c}_HOST="
              . $self->env->getNodeAddress( $m->{'node'} )
              . ' ' );
        $c++;
    }
    $c--;
    $self->mdsopt( "MDSCOUNT=$c" . $self->mdsopt );

    $self->ossopt('');
    $c = 1;
    foreach my $m (@$osss) {
        $self->ossopt( $self->ossopt
              . " OSTDEV$c="
              . $m->{'device'}
              . " ost${c}_HOST="
              . $self->env->getNodeAddress( $m->{'node'} )
              . ' ' );
        $c++;
    }
    $c--;
    $self->ossopt( "OSTCOUNT=$c" . $self->ossopt );

    #include only master client for sanity suite
    $self->clntopt('CLIENTS=');
    my $mclient;
    my @rclients;
    foreach my $cl (@$clietns) {
        if ( ( defined( $cl->{'master'} ) && ( $cl->{'master'} eq 'yes' ) ) ) {
            $mclient = $self->env->getNodeAddress( $cl->{'node'} );
        }
        else {
            push @rclients, $self->env->getNodeAddress( $cl->{'node'} );
        }
    }
    $self->clntopt(
        "CLIENTS=$mclient RCLIENTS=\\\"" . join( ',', @rclients ) . "\\\"" );
}

__PACKAGE__->meta->make_immutable;

1;

