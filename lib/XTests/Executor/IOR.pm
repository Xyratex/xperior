#
#===============================================================================
#
#         FILE:  IOR.pm
#
#  DESCRIPTION:  Module which contains IOR specific execution functionality. 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex 
#      VERSION:  1.1
#      CREATED:  10/08/2011 
#===============================================================================
=pod
=head1 DESCRIPTION

IOR wrapper module for XTests harness.

=cut

package XTests::Executor::IOR;
use Moose;
use Data::Dumper;
#use MooseX::Storage;
use Carp qw( confess cluck );

extends 'XTests::Executor::SingleProcessBase';

our $VERSION = "0.0.1";

has mfile   => (is=>'rw');
has clients => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        addClient    => 'push',
        getClients   => 'elements',
    },
);
has machinefile => (is=>'rw');
has machines => (is=>'rw');
    
after 'init' => sub{
    my $self    = shift;
    $self->appname('IOR');
    $self->reset;
};

=over *

=item execute

I<execute> is inherit from XTests::Executor::SingleProcessBase class.

=back

=over *

=item reset

Reset previously generated values, f.e. clients list.

=back

=cut

sub reset{
    my $self    = shift;
    my $clients = $self->env->getClients;
    $self->cmd('');
    my @e;
    $self->clients(\@e);
    #$self->mfile("/tmp/ior_machinefile");
}


#now is not used, for possible future usage
#have bug in machinefile usage
#sub _prepareCommandsMpich2{
#    my $self    = shift;
#    $self->reset; 
#
#    #no any filtering now, create list of clients nodes 
#    foreach my $lc (@{$self->env->getClients}){
#        my $nid = $lc->{'node'};
#        my $ad = $self->env->getNodeAddress($nid);
#        $self->addClient($ad);
#    }
#    my %csh;
#    foreach my $c ($self->getClients){
#        $csh{$c}=1;
#    }
#    my $mf = '';
#    my $qc = 0;
#    foreach my $c ( keys %csh){
#        $mf = "$mf\n" if $mf ne '' ;
#        $mf = $mf."$c:1";
#        $qc++;
#    }
#    $self->machinefile($mf);
#    my $mp = $self->env->cfg->{'client_mount_point'};
#    my $tf = $self->env->cfg->{'benchmark_tests_file'};
#    
#    my $c = $self->test->getParam('iorcmd');
#    
#    $c =~ s/\@mount_point\@/$mp/g;
#    $c =~ s/\@test_file\@/$tf/g;
#     
#    $self->cmd("mpiexec   -machinefile ".$self->mfile." -n $qc  $c");
#}

=over *

=item _prepareCommands

_prepareCommands - generate commands for executing ior in  openmpi  environment. 

=back

=cut
sub _prepareCommands{
    my $self    = shift;
    $self->reset; 

    #no any filtering now, create list of clients nodes 
    foreach my $lc (@{$self->env->getClients}){
        my $nid = $lc->{'node'};
        my $ad = $self->env->getNodeAddress($nid);
        $self->addClient($ad);
    }
    my %csh;
    foreach my $c ($self->getClients){
        $csh{$c}=1;
    }
    my $mf = '';
    foreach my $c ( keys %csh){
        $mf = "$mf," if $mf ne '' ;
        $mf = $mf."$c";
    }
    $self->machines($mf);
    my $mp = $self->env->cfg->{'client_mount_point'};
    my $tf = $self->env->cfg->{'benchmark_tests_file'};
    
    my $c = $self->test->getParam('iorcmd');
    
    $c =~ s/\@mount_point\@/$mp/g;
    $c =~ s/\@test_file\@/$tf/g;
     
    $self->cmd("/usr/lib64/openmpi/bin/mpirun  -H ".$self->machines." -pernode  --prefix /usr/lib64/openmpi/  $c");
}
 
__PACKAGE__->meta->make_immutable;

1;
