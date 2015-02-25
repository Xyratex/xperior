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
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::ReformatBefore - Role implements reformat from
master client host for Lustre cluster

=head1 DESCRIPTION

Role implements Lustre reformatting fs before every test. It uses
b<llmount.sh> and b<llmountcleanup.sh> Lustre scripts.
If format failed then test will set to fail without test execution
and additionally set b<format_fail=yes> which leads Xperior to
exit for cluster restart with exit code 13 L<Xperior::Core>.

Logs are collected and attached to test results.



=cut

package Xperior::Executor::Roles::ReformatBefore;
#order is important!
use Error qw(try finally except otherwise);
use Xperior::Xception;
use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use File::Slurp;

requires 'env';

around 'execute' => sub {
    my $orig = shift;
    my $self = shift;
    my $llmountcmd = $self->_prepareCommands('llmount.sh','FORMAT=yes');
    my $llcleanupcmd = $self->_prepareCommands('llmountcleanup.sh');
    try{
    #cleanup
        my $mo = $self->env->getNodeById(
                $self->_getMasterNode()->{'node'});
        my $master = $mo->getRemoteConnector();
        my $resc = $master->run($llcleanupcmd,timeout => 300);
        DEBUG 'llmountcleanup out:'.$resc->{stdout};
        DEBUG 'llmountcleanup err:'.$resc->{stderr};
        my $llcec =  'not set';
        $llcec = $resc->{exitcode} if defined $resc->{exitcode};
        $self->addYE('ReformatBefore_llmountcleanup_exitcode',
                            $llcec );
        $self->addYE('ReformatBefore_llmountcleanup_cmd',
                            $llcleanupcmd);
        $self->writeLogFile('ReformatBefore_llmountcleanup.stdout',
                            $resc->{stdout});
        $self->writeLogFile('ReformatBefore_llmountcleanup.stderr',
                            $resc->{stderr});
        if($llcec != 0){
            ERROR 'llmountcleanup failed';
            $self->addMessage('ReformatBefore: llmountcleanup failed');
            throw RemoteCallException(
                    "ReformatBefore: llmountcleanup failed");
        }
        $self->addMessage('ReformatBefore: llmountcleanup passed');
        #llmount
        my $resm = $master->run($llmountcmd,timeout => 300);
        my $llmec = 'not set';
        $llmec =  $resm->{exitcode} if defined  $resm->{exitcode};
        $self->addYE('ReformatBefore_llmount_exitcode', $llmec);
        $self->addYE('ReformatBefore_llmount_cmd',
                            $llmountcmd);
        $self->writeLogFile('ReformatBefore_llmount.stdout',
                            $resm->{stdout});
        $self->writeLogFile('ReformatBefore_llmount.stderr',
                            $resm->{stderr});
        DEBUG 'llmount w reformat out:'.$resm->{stdout};
        DEBUG 'llmount w reformat err:'.$resm->{stderr};
        if($llmec != 0){
            ERROR 'llmount failed';
            $self->addMessage('ReformatBefore: llmount failed');
            throw RemoteCallException(
                            "ReformatBefore: llmount failed");
        }
        $self->addMessage('ReformatBefore: llmount passed');
        $orig->($self);
    }catch RemoteCallException Error::subs::with{
        #pass ("Exception cought");
        ERROR "Exception caught, faling test";
        $self->addYE('format_fail', 'yes');
        $self->fail("Failed on ReformatBefore");
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

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut


