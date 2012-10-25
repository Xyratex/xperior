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

Xperior::Executor::Roles::GetDiagnostics - Call lustre-diagnostic on every node and get xml results

=head1 DESCRIPTION

The module contains function which called after every execution for harvest diagnostic information from nodes which defined in configuration.

The module requests setup of lustre-diagnostic package on every node in cluster.

Result of the module is file C<(testid).diagnostic.xml.(node id>.log>

For enable this module for test or test group add to C<roles> property string C<GetDiagnostics>

=cut

package Xperior::Executor::Roles::GetDiagnostics;

use strict;
use warnings;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;

requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';

after 'execute' => sub {
    my $self = shift;
  if ( ( $self->yaml->{status_code} ) == 1 ) {    #test failed
   foreach my $n (@{$self->env->nodes}){
        my $c = $n->getExclusiveRC;
        my $td = '/tmp/xpdiagnostic.'
                    .Time::HiRes::gettimeofday().'.xml';

        $c->createSync("/usr/sbin/lustre-diagnostics -x $td",300);

        my $res = $c->getFile( $td,
            $self->getNormalizedLogName('diagnostic.xml.'.$n->id));
            if ($res == 0){
                $self->registerLogFile('diagnostic.xml.'.$n->id,
                     $self->getNormalizedLogName
                                ('diagnostic.xml.'.$n->id));
            }else{
                $self->addMessage(
                    "Cannot copy log file [$td]: $res");

            }


        }
   }

};

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


