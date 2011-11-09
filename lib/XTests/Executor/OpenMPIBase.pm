#
#===============================================================================
#
#         FILE:  OpenMPIBase.pm
#
#  DESCRIPTION:  Module which contains OpenMPI specific execution functionality. 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex 
#      CREATED:  11/01/2011 
#===============================================================================
=pod
=head1 DESCRIPTION

B<OpenMPI>  module for XTests harness. Provides fuctions for command line 

=cut

package XTests::Executor::OpenMPIBase;
use Moose;
use Data::Dumper;
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
has machines => (is=>'rw');
has cmdfield => (is=>'rw');
   
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
}


=over *

=item _prepareCommands

_prepareCommands - generate commands for executing cmd in  openmpi  environment. 

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
    my $td = $self->env->cfg->{'tempdir'}
    ;
    my $c = $self->test->getParam( $self->cmdfield );
    
    $c =~ s/\@mount_point\@/$mp/g;
    $c =~ s/\@test_file\@/$tf/g;
    $c =~ s/\@tempdir\@/$td/g;

    $self->cmd("/usr/lib64/openmpi/bin/mpirun  -H ".$self->machines." -pernode  --prefix /usr/lib64/openmpi/  $c");
}
 
__PACKAGE__->meta->make_immutable;

1;
