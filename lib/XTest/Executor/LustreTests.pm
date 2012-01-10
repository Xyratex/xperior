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

has 'mdsopt'  => (is=>'rw');
has 'ossopt'  => (is=>'rw');
has 'clntopt' => (is=>'rw');
has 'reason'  => (is=>'rw');

after 'init' => sub{
    my $self    = shift;
    $self->appname('sanity');
    #$self->reset;
    $self->reason(''); 
};


sub getReason{
    my $self    = shift;
    return $self->reason;
}

sub _prepareCommands{
    my $self = shift;
    $self->_prepareEnvOpts;
    my $td = '';
    $td = $self->env->cfg->{'tempdir'} if defined $self->env->cfg->{'tempdir'};
    my $dir    =$self->env->cfg->{'client_mount_point'}.$td;
    my $tid    = $self->test->testcfg->{id};
    my $script = $self->test->getParam('groupname');
    if( defined( $self->test->getParam('script'))){
        $script = $self->test->getParam('script');
        $tid = 1;#default test number  
    }
    
#REFORMAT=YES
    $self->cmd("SLOW=YES  ".$self->mdsopt." ".$self->ossopt." ".$self->clntopt." ONLY=$tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -S -w \\\" /usr/lib64/lustre/tests/${script}.sh");
#    $self->cmd("SLOW=YES  ".$self->mdsopt." ".$self->ossopt." ".$self->clntopt." ONLY=$tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -S -w \\\"  ACC_SM_ONLY=${script} /usr/lib64/lustre/tests/acceptance-small.sh");

}

sub processLogs{
    my ($self, $file) = @_;
    DEBUG ("Processing log file [$file]");
    open (F, "  $file");

    my $passed=-1;
    my @results;
    while ( defined (my $s = <F>)) {
        chomp $s;
        if( $s =~ m/PASS/){
            $passed=0;
        }
        if( $s =~ m/FAIL:(.*)/){
            $self->reason($1);
        }
    }
    close (F);
    return $passed;
}

sub _prepareEnvOpts{
    my $self    = shift;
    my $mdss    = $self->env->getMDSs;
    my $osss    = $self->env->getOSSs;
    my $clietns = $self->env->getClients;
    $self->mdsopt('');
    my $c = 1;
    foreach my $m (@$mdss){
        $self->mdsopt(
          $self->mdsopt.
          " MDSDEV$c=".$m->{'device'}.
          " mds${c}_HOST=".$self->env->getNodeAddress($m->{'node'}).
          ' ');
        $c++;
    }
    $c--;
    $self->mdsopt("MDSCOUNT=$c".$self->mdsopt);

    $self->ossopt('');
    $c = 1;
    foreach my $m (@$osss){
        $self->ossopt(
          $self->ossopt.
          " OSTDEV$c=".$m->{'device'}.
          " ost${c}_HOST=".$self->env->getNodeAddress($m->{'node'}).
          ' ');
        $c++;
    }
    $c--;
    $self->ossopt("OSTCOUNT=$c".$self->ossopt);

    #include only master client for sanity suite
    $self->clntopt('CLIENTS=');
    my $mclient;
    my @rclients;
    foreach my $cl (@$clietns){
        if( (defined ($cl->{'master'} ) &&
            ($cl->{'master'} eq 'yes') ) ){
            $mclient=$self->env->getNodeAddress($cl->{'node'});
        }else{
            push @rclients, $self->env->getNodeAddress($cl->{'node'});
        }
    }
    $self->clntopt
        ("CLIENTS=$mclient RCLIENTS=\\\"".join(',',@rclients)."\\\"");
}

__PACKAGE__->meta->make_immutable;

1;

