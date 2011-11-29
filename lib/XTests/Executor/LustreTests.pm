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
package XTests::Executor::LustreTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);

extends 'XTests::Executor::SingleProcessBase';

our $VERSION = "0.0.1";

has 'mdsopt'  => (is=>'rw');
has 'ossopt'  => (is=>'rw');
has 'clntopt' => (is=>'rw');

after 'init' => sub{
    my $self    = shift;
    $self->appname('sanity');
    #$self->reset;
};


sub _prepareCommands{
    my $self = shift;
    $self->_prepareEnvOpts;
    my $tid = $self->test->testcfg->{id}; 
    $self->cmd("SLOW=YES REFORMAT=YES ".$self->mdsopt." ".$self->ossopt." ".$self->clntopt." ONLY=$tid DIR=/mnt/lustre/tmp  PDSH=\\\"/usr/bin/pdsh -S -w \\\" /usr/lib64/lustre/tests/sanity.sh");
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

