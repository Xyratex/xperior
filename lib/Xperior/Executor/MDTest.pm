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

Xperior::Executor::MDTest - Module which contains MDTest specific execution functionality

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

