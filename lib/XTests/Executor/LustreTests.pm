#
#===============================================================================
#
#         FILE:  LustreTests.pm
#
#  DESCRIPTION: Module which contains IOR specific execution functionality
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      VERSION:  1.0
#      CREATED:  09/27/2011 11:47:51 PM
#===============================================================================
package XTests::Executor::LustreTests;
use Moose;
use Data::Dumper;
use MooseX::Storage;
use Carp qw( confess cluck );

extends 'XTests::Executor::Base';

has 'mdsopt'  => (is=>'rw');
has 'ossopt'  => (is=>'rw');
has 'clntopt' => (is=>'rw');

sub execute{

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
#TODO no do this option now
#$self->clntopt('CLIENTS=');
#    my $c = 1;
#    foreach my $m (@$clietns){
#        $self->clntopt(
#          $self->clntopt.
#          " MDSDEV$c=".$m->{'device'}.
#          " mds${c}_HOST=".$self->env->getNodeAddress($m->{'node'}).
#          ' ');
#        $c++;                                                       
#        }
}

__PACKAGE__->meta->make_immutable;

1;

