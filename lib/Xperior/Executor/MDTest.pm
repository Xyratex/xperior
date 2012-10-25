#
#===============================================================================
#
#         FILE:  MDTest.pm
#
#  DESCRIPTION:  Module which contains MDTest specific execution functionality. 
#
#       AUTHOR:   ryg 
#      COMPANY:  Xyratex 
#      CREATED:  11/01/2011 
#===============================================================================
=pod

=head1 DESCRIPTION

B<mdtest> wrapper module for Xperior harness. Pretty same to IOR wrapper,
in future must be one class for both tests.

=cut

package Xperior::Executor::MDTest;
use Moose;
use Log::Log4perl qw(:easy);

extends 'Xperior::Executor::OpenMPIBase';

after 'init' => sub{
    my $self    = shift;
    $self->appname('mdtest');
    $self->cmdfield('mdtestcmd');
    $self->reset;
};

=head2 Public fields and supported constructor parameters

=head3 processLogs

parse output for get benchmark results 

=cut 

sub processLogs{
    my ($self, $file) = @_;
    DEBUG ("Processing log file [$file]");
    open (F, "  $file");

    my @results;
    while ( defined (my $s = <F>)) {
        chomp $s;
        #DEBUG $s;
        if( $s =~ m/(\w+\s+\w+)\s*:\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)$/ ){
            #DEBUG ('*********************'.$1);
            my %metric=(
                name=>$1,
                higherisbetter=>1,
                max_value=>$2,
                min_value=>$3,
                mean_value=>$4,
                stddev_value=>$5,
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
