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
use Log::Log4perl qw(:easy);

extends 'XTests::Executor::OpenMPIBase';


after 'init' => sub{
    my $self    = shift;
    $self->appname('IOR');
    $self->cmdfield('iorcmd');
    $self->reset;
};

=over 

=item *
 processLogs - parse output for get benchmark results 

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
