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

Xperior::Executor::LustreSingleTests - Module which contains Lustre execution
functionality for single test, e.g. runtests

=head1 DESCRIPTION

Module which contains Lustre execution specific functionality

LustreTests execution module for Xperior harness. This module inherit
L<Xperior::Executor::SingleProcessBase> and provide functionality for
generating command line  for Lustre B<test-framework.sh> based tests
and parse these tests output.

Sample test descriptor there C<testds/sanity_tests.yaml>.

=cut

package Xperior::Executor::LustreSingleTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);

extends 'Xperior::Executor::LustreTests';

after 'init' => sub {
    my $self = shift;
    $self->appname('single');
    $self->reason('');
};


=head3 processLogs 

This executor for lustre tests which don't needed log 
parsing, just replace it to pretty simple function
with static result.

Return values:
    Xperior::Executor::SingleProcessBase::PASSED   - passed

=back

=cut

sub processLogs {
    my ( $self, $file ) = @_;

    my $mclient    = $self->_getMasterClient();
    my $mclientobj = $self->env->getNodeById( $mclient->{'node'} );
    my $connector  = $mclientobj->getRemoteConnector();

    DEBUG("Processing log file [$file]");
    open(F, "  $file");
    while ( defined( my $s = <F> ) ) {
        chomp $s;
        $self->_parseLogFile($s,$connector);
    }
    close(F);
    return $self->PASSED;
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

