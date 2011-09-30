#
#===============================================================================
#
#         FILE:  XTests/Test.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  08/30/2011 11:49:56 PM
#     REVISION:  ---
#===============================================================================

package XTests::Test;
use Moose;
use Data::Dumper;
use MooseX::Storage;

our $VERSION = '0.01';
with Storage('format' => 'JSON', 'io' => 'File');


has 'testcfg'              => ( is => 'rw');
has 'groupcfg'             => ( is => 'rw');

sub init {
    my $self    = shift;
    $self->{'testcfg'}    = shift;
    $self->{'groupcfg'}   = shift;
}

sub getParam{
    my $self    = shift;
    my $pname   = shift;
    return $self->{'testcfg'}->{$pname} if (defined($self->{'testcfg'}->{$pname} ));
    return $self->{'groupcfg'}->{$pname} if (defined($self->{'groupcfg'}->{$pname} ));

    return undef;
}

sub getDescription{

}

sub start{

}

sub getStatus {

}

sub collec{

}

sub clean{

}

__PACKAGE__->meta->make_immutable;

1;
