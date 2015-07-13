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
# Copyright 2015 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::SubTestResult - Definition of subtest result

=head1 DESCRIPTION

Class is inhertor of L<Xperior::TestResultBase>.

Class defines sub test specific behavior. Subtest is
part of test which is executed as part of full tests,
e.g. in case of parallel execution every process is
subtest.


=head1 FUNCTIONS


=cut


package Xperior::SubTestResult;
use Moose;
use Data::Dumper;
use Log::Log4perl qw(:easy);

our $VERSION = '0.1';
extends 'Xperior::TestResultBase';

has 'owner'              => ( is => 'rw');
#has 'yaml'              => ( is => 'rw');

sub _reportDir{
    my $self = shift;
    return $self->owner()->options->{'workdir'}.'/'.
           $self->owner()->test->getParam('groupname');
}

#TODO add test
sub _resourceFilePrefix{
    my $self = shift;
    return $self->_reportDir.'/'.
           $self->owner()->test->getId().'.';
}


#memory-only
sub _write{

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

Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

