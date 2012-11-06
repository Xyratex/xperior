#
# GPL HEADER START
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 only,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License version 2 for more details (a copy is included
# in the LICENSE file that accompanied this code).
#
# You should have received a copy of the GNU General Public License
# version 2 along with this program; If not, see http://www.gnu.org/licenses
#
# Please  visit http://www.xyratex.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

=pod

=head1 NAME

Xperior::Executor::IOR - IOR execution module for Xperior harness

=head1 DESCRIPTION

IOR execution module for Xperior harness. This module inherit
L<SingleProcessBase> and provide only parsing for B<iorcmd> parameter from
test descriptor. This parameter is obligatory for test and should contains
correct command for executing IOR. Sample test descriptor
there C<testds/ior_tests.yaml>.


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

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 only,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License version 2 for more details (a copy is included
in the LICENSE file that accompanied this code).

You should have received a copy of the GNU General Public License
version 2 along with this program; If not, see http://www.gnu.org/licenses



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

