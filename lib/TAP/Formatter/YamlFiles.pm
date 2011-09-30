#
#===============================================================================
#
#         FILE: TAP/Formatter/YamlFiles.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  ryg
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/19/2011 12:36:00 PM
#     REVISION:  ---
#===============================================================================
package TAP::Formatter::YamlFiles;

use strict;
use warnings;
use TAP::Base ();
use TAP::Formatter::Base ();
use TAP::Formatter::Yaml::Session;
use POSIX qw(strftime);

use Data::Dumper;
use Log::Log4perl qw(:easy);
use YAML qw ( Dump DumpFile );
use Carp qw(cluck);

use vars qw($VERSION @ISA);

@ISA = qw(TAP::Formatter::Base);

=head1 NAME

TAP::Formatter::Files - Harness output delegate for  output to files set, every test has own output yaml file with all details

=head1 VERSION

Version 0.1

=cut

$VERSION = '0.1';

=head1 DESCRIPTION

This provides file orientated output formatting for TAP::Harness.

=head1 SYNOPSIS

 use TAP::Formatter::File;
 my $harness = TAP::Formatter::File->new( \%args );

=head2 C<< open_test >>

See L<TAP::Formatter::base>

=cut

sub _initialize {
    my ( $self, $arg_for ) = @_;
    $arg_for ||= {};
    print Dumper $arg_for ;
    
    $self->{'workdir'} = delete $arg_for->{'workdir'};

    $self->SUPER::_initialize($arg_for);
    my %arg_for = %$arg_for;    # force a shallow copy


    return $self;
}


sub open_test {
    my ( $self, $test, $parser ) = @_;
    $self->{'name'} = $test;  
    DEBUG "YamlFiles formater is working with test [$test]";
    my $session = TAP::Formatter::Yaml::Session->new(
        {   name      => $test,
            formatter => $self,
            parser    => $parser,
        }
    );

    $session->header;

    return $session;
}

sub _should_show_count {
    return 0;
}

sub _write_test_result{
    my $self   = shift;
    #my $result = shift;
    #print Dumper $self;
    my $file =  $self->{'workdir'}.'/'.$self->{'name'}.'.yaml';
    # TODO add rewrite protection
    #   unless( -e $self->{'workdir'}.'/'.$self->{'test'} ){
    #
    #    }
    
    DEBUG "Put test result to file [$file]";
    #DEBUG "RAW out:\n".$self->{'str'}."\n";
    my $yamlstart = 0;
    my $yaml = "";
    foreach my $s ( split("\n",$self->{'str'}) ){
        if( $yamlstart == 1 ){
            $yaml=$yaml."\n".$s;
        }elsif( $s =~ m/^---/){
            $yamlstart=1;
        }

    }
    DEBUG "YAML out:\n $yaml \n";
    #DumpFile($file, $self->{'str'});
    #print { $self->stdout } @_ ;
    #print { $self->stdout } "!!!!!!!!!!!!!!";
    $self->{'str'}="";
}

sub _save_test_by_string{
    my $self   = shift;
    #my $str    = shift;
    #push @($self->raw), $str;
    #print "!!!" .  @_[0]->raw."\n";
    $self->{'str'} ="" unless defined $self->{'str'} ;
    $self->{'str'} = $self->{'str'} . $_[0]->raw."\n";
}

sub _output {
    my $self = shift;
    print { $self->stdout } @_ ;
#cluck("In _output:\n\n");
}

1;

