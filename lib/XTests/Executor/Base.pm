#
#===============================================================================
#
#         FILE:  Base.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/30/2011 01:31:34 AM
#     REVISION:  ---
#===============================================================================
package XTests::Executor::Base;
#use YAML qw "Bless Dump";
use Moose;
use Data::Dumper;
#use YAML::Dumper;
#use TAP::Parser::YAMLish::Writer;
use YAML::Tiny;

has 'test'              => ( is => 'rw');
has 'result'            => ( is => 'rw');
has 'result_code'       => ( is => 'rw');
has 'yaml'              => ( is => 'rw');

sub init{
    my $self = shift;
    my $test = shift;
    $self->{'test'} = $test;
}

sub addYE{
    my ($self, $key, $value) = @_;
    $self->{'yaml'}->{$key} = $value ;
}

sub pass{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = "#".$msg 
    }else{
        $msg='';
    }
    $self->{'result'} ="ok 1 $msg"; 
    $self->{'result_code'} = 0;
}

sub fail{
    my ($self,$msg)  = @_;
    if( defined $msg){
        $msg = "#".$msg 
    }else{
        $msg='';
    }
    $self->{'result'} ="not ok 1 $msg" ;
    $self->{'result_code'} = 1;
}


sub addLogFile{
    my ($self,$key,$path)  = @_;
    confess("Not implemented");
}

sub createLogFile{
    my ($self,$key,$path)  = @_;
    confess("Not implemented");
    #return FD;
}

sub tap{
    my $self = shift;
    #print STDERR "******\n".Dumper $self->{'yaml'};
    $self->addYE('result',$self->result);
    #my $dumper = TAP::Parser::YAMLish::Writer->new;
    my $yaml='';
    #$dumper->write($self->{'yaml'}, \$yaml );
    $yaml = Dump($self->{'yaml'});
    my $out=
        "TAP version 13\n".
        "1..1\n".
        $self->result."\n".
        $yaml;
}

__PACKAGE__->meta->make_immutable;

1;

