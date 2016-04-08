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
# Copyright 2015 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::CustomLogCollector - Role implemnts harvesting
logs from predefined places

=head1 DESCRIPTION

The role implements logs collection from nodes which defined
in system configs file. Logs for collecting should be defined
as test or test group property.

   collect_logs:
        - '/var/logs/mero-.*\.log'
        - '/qqq/www/.*'

For templates shell masks should be used (as for b<ls>).
Logs will not be collected in  node crash case.

=cut

package Xperior::Executor::Roles::CustomLogCollector ;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use File::Basename;
use Xperior::RemoteHelper;
our $VERSION = "0.0.1";

has logname   => ( is => 'rw', default => 'messages');
requires    'env', 'addMessage', 'getNormalizedLogName', 'registerLogFile';
my $title = 'CustomLogCollector';

after   'execute' => sub{
    my $self    = shift;
    if(not defined($self->test->getParam('collect_logs'))){
        DEBUG "No logs for collection is defined";
        return;
    }
    $self->beforeAfterExecute($title);
    foreach my $node (@{$self->env->nodes}) {
        my $logs = $self->test->getParam('collect_logs');
        collect_remote_files_by_mask($node,$self,$logs);
    }
    $self->afterAfterExecute($title);
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



Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut


