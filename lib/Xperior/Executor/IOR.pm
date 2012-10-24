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

IOR execution module for Xperior harness. This module inherit L<SingleProcessBase> and provide only parsing for B<iorcmd> parameter from test descriptor. This parameter is obligatory for test and should contains correct command for executing IOR. Sample test descriptor there C<testds/ior_tests.yaml>. 



=cut

package Xperior::Executor::IOR;
use Moose;
use Log::Log4perl qw(:easy);

extends 'Xperior::Executor::OpenMPIBase';


after 'init' => sub{
    my $self    = shift;
    $self->appname('IOR');
    $self->cmdfield('iorcmd');
    $self->reset;
};

=over 

=item *
processLogs - parse output for benchmark results. Tested on output from IOR 2.10.x. 

=back

=cut 

sub processLogs{
    my ($self, $file) = @_;
    DEBUG ("Processing log file [$file]");
    open (F, "  $file");

    my @results;
    while ( defined (my $s = <F>)) {
        chomp $s;
        #DEBUG $s;
        if( $s =~ m/write\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)/ ){
            DEBUG ('*********************'.$1);
            my %metric=(
                name=>'write',
                higherisbetter=>1,
                max_value=>$1,
                min_value=>$2,
                mean_value=>$3,
                stddev_value=>$4,
            );
            push @results, \%metric;
        }
        #DEBUG $s;
        if( $s =~ m/read\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)/ ){
            DEBUG ('*********************'.$1);
            my %metric=(
                name=>'read',
                higherisbetter=>1,
                max_value=>$1,
                min_value=>$2,
                mean_value=>$3,
                stddev_value=>$4,
            );
            push @results, \%metric;
        }
    }
    close (F);
    $self->addYE('measurements',\@results);
    return 0;
}


__PACKAGE__->meta->make_immutable;

1;
