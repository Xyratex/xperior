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
# Copyright 2016 Seagate
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Examples::Simple

=head1  DESCRIPTION

The module is sample test for Xperior, it shows ways to write
tests and describes test structure, access to configuration.

Configuration which used for testing B<t/testcfgs/testsystemcfg_generic.yaml>

Corresponding test descriptor B<testds/xperior-example_tests.yaml>


=cut

package Examples::Simple;

use strict;
use warnings;

#use it for excpetions
use Error  qw(try finally except otherwise);
#Xperior is using Moose as OOP subsystem
use Moose;
#use it for logging isntead of  stdout/stderr!
use Log::Log4perl qw(:easy);
#set of predefined Xperior exceptions
use Xperior::Xception;
#Moose parent class
extends 'TAPI::SimpleTest';

#it is good idea to set version
our $VERSION = '0.01';

=head3 error_test

This testcase ended with error. Error indicates issues
in test or framework code which makes next execution
impossible or meaningless.

=cut

sub error_test {
    #processing parameters
    my $self = shift;
    # set status directly
    $self->error(message => 'Fail as ERROR');

}

=head3 fail_test

 This testcase ended with fail. 'Fail' indicates that
 test goal is not achieved, 'test failed'

=cut

sub fail_test {
    my $self = shift;
    # set status directly
    $self->fail(message => 'Fail test by direct call');

}

=head3 contains_test

This testcase shows how to use B<contains> check.

=cut

sub contains_test {
    my $self = shift;

    # use default contains
    $self->contains(
        value     => 'qwerty asdfg',
        expected => 'qwerty',
        message  => "Contains chech");

    # use default not contains
    # if B<not_expected> set to string and B<expected> not set,
    # this check works as 'not contains'
    $self->contains(
        value        => 'qwerty asdfg',
        not_expected => 'zzzz',
        message      => "not contains chech");

    # use custom check function, B<not_expected> is not applicable
    $self->contains(
        value      => 'qwerty asdfg ZZZZ',
        expected   => 'zzzz',
        check_sub  => sub {$_[0] =~ m/$_[1]/i},
        message    => "custom chech sub");

}

=head3 run_check_test

This testcase shows how to use B<run_check> check.

=cut

sub run_check_test {
    my $self = shift;
    #accesss to Xperior::TestEnvironment
    #for manipulation with configuration
    my $env = $self->executor()->env();

    #get master client from GenericObjects section
    # from system config yaml
    my $client = $env->get_master_generic_clients();
    #find ssh connector by node id
    my $client_ssh = $env->get_node_connector_by_id($client->{node});

    #get 'client_mount_point' from system config
    my $mount = $env->{cfg}->{'client_mount_point'};

    # use default contains, run only
    $self->run_check(
        node   => $client_ssh,
        cmd     =>"ls -la $mount/file_not_exists ",
        should_fail => 1,
        message =>'Negative execution check');

    $self->run_check(
        node   => $client_ssh,
        cmd     =>"ls -la $mount/file_not_exists ",
        sub_exec_check => sub {
            return 0 if $_[0];
            return 1 if $_[1] == 2;
            return 0;
        },
        message =>'Custom sub execution check');

    # example of directr search to specially marked object
    # full config see in t/testcfgs/testsystemcfg_generic.yaml
    #   - id          : ssu3
    #     node        : local1
    #     type        : failing_drive

    my $node_failing_drive;
    foreach my $o (@{$env->cfg->{'GenericObjects'}}){
        if( $o->{'type'} eq 'failing_drive'){
            $node_failing_drive =  $o;
        }
    }
    my $node_failing_drive_ssh   = $env->get_node_connector_by_id(
                                        $node_failing_drive->{'node'}
                                        );

    #access to test descriptor and reading a field
    my $cf = $self->testds()->getParam('custom_field');

    # now we could run command or do check on selected node
    $self->run_check(
        node     => $node_failing_drive_ssh,
        cmd      => "echo 'param:$cf'",
        contains => 'remove drive there',
        message  =>'run_check with contains');


}

1; #perl module end

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



Copyright 2016 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

