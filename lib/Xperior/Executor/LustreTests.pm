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
=pod

=head1 DESCRIPTION

LustreTests execution module for Xperior harness. This module inherit 
L<Xperior::Executor::SingleProcessBase> and provide functionality for
generating command line  for Lustre B<test-framework.sh> based tests
and parse these tests output.

Sample test descriptor there C<testds/sanity_tests.yaml>. 
=cut

package Xperior::Executor::LustreTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);

extends 'Xperior::Executor::SingleProcessBase';

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

=head2 Functions

=over 12

=item * B<getReason> - return failure reason if it found while test 
log parsed.

=back

=cut

sub getReason {
    my $self = shift;
    return $self->reason;
}

=over 12

=item * B<_prepareCommands> - generate command line for Lustre test based on L<configuration|XperiorUserGuide/"System descriptor"> and test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    $self->_prepareEnvOpts;
    my $td  = '';
    my $ext = '.sh';
    $td = $self->env->cfg->{'tempdir'} if defined $self->env->cfg->{'tempdir'};
    my $dir    = $self->env->cfg->{'client_mount_point'} . $td;
    my $tid    = 'ONLY=' . $self->test->testcfg->{id};
    my $script = $self->test->getParam('groupname');
    my $eopts  = '';
    #TODO add test on it
    $eopts = $self->env->cfg->{extoptions} 
                if defined $self->env->cfg->{extoptions};
    if ( defined( $self->test->getParam('script') ) ) {
        $script = $self->test->getParam('script');
        $tid    = '';                                #no default test number
        $ext = '';    #ext must be set also when script is set
    }

    $self->cmd( "SLOW=YES  "
          . $self->mdsopt . " "
          . $self->ossopt . " "
          . $self->clntopt
          . " $eopts $tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -R ssh -S -w \\\" /usr/lib64/lustre/tests/${script}${ext}"
    );

}

=over 12

=item * B<processLogs> - parse B<test-framework.sh> test output and
calculate result based on output parsing.

Return values:

    0   - passed
    1   - skipped
    10  - failed
    100 - no result set based on parsing, failed toor

Also failure reason accessible (if defined) via call C<getReason>.

=back

=cut 

sub processLogs {
    my ( $self, $file ) = @_;
    DEBUG("Processing log file [$file]");
    open( F, "  $file" );

    my $passed = 100;
    my $defreason = 'No_status_found';
    my $reason = $defreason;
    my @results;
    #consider only last keywords! 
    while ( defined( my $s = <F> ) ) {
        chomp $s;
        if ( $s =~ m/PASS/ ) {
            $passed = 0;
            $reason = '';
        }
        if ( $s =~ m/FAIL:(.*)/ ) {
            $passed = 10;
            if( $reason eq $defreason){ 
                $reason = $1 if defined $1;
            }else{
                $reason = "$reason\n$1" if defined $1;
            }
        }
        if ( $s =~ /SKIP:(.*)/ ) {
            $passed = 1;
            $reason = $1 if defined $1;;            
        }
        #don't see next messages after test end 
        #================== 05:28:17
        if ( $s =~ /test\s+complete.*=+\s+\d\d:\d\d:\d\d\s+/){
            last;
        }
    }
    if ($passed) {
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
        my $md = '';
        if((defined($m->{'device'})) 
                and($m->{'device'} ne '')){
            $md =  "MDSDEV$c=".$m->{'device'};

        }
        $self->mdsopt( $self->mdsopt
              . " $md mds${c}_HOST="
              . $self->env->getNodeAddress( $m->{'node'} ).' '
              . " mds_HOST=" 
              . $self->env->getNodeAddress( $m->{'node'} ).' '
              );
        $c++;
    }
    $c--;
    $self->mdsopt( "MDSCOUNT=$c" . $self->mdsopt );

    $self->ossopt('');
    $c = 1;
    foreach my $m (@$osss) {
        my $sd = '';
        if((defined($m->{'device'}))
                and($m->{'device'} ne '')){
            $sd =  " OSTDEV$c=". $m->{'device'}

        }
        $self->ossopt( $self->ossopt
              . " $sd  ost${c}_HOST="
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

