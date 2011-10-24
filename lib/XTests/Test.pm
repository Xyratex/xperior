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
use Log::Log4perl;

our $VERSION = '0.01';
with Storage('format' => 'JSON', 'io' => 'File');


has 'testcfg'              => ( is => 'rw');
has 'groupcfg'             => ( is => 'rw');
has 'tap'                  => ( is => 'rw');
has 'results'              => ( is => 'rw');

sub init {
    my $self    = shift;
    $self->{'testcfg'}    = shift;
    $self->{'groupcfg'}   = shift;
}


sub getName{
    my $self = shift;
    return $self->testcfg->{'name'} if (defined($self->testcfg->{'name'} ));
    return $self->testcfg->{'id'};    
}


sub getParamNames{
    my $self = shift;
    my @names;
    foreach my $n (keys %{$self->testcfg}){
        push @names, $n;
    }
    foreach my $n (keys %{$self->groupcfg}){
        push @names, $n;
    }
    #print Dumper \@names;
    return \@names;
}

sub getParam{
    my $self    = shift;
    my $pname   = shift;
    return $self->testcfg->{$pname} if (defined($self->testcfg->{$pname} ));
    return $self->groupcfg->{$pname} if (defined($self->groupcfg->{$pname} ));

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
