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

Xperior::Executor::XperiorTests - Module which contains code for executing Xperior scenarios

=head1 DESCRIPTION

TBD

=cut
package Xperior::Executor::XperiorTests;
use Moose;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp qw( confess cluck );
use File::Path;
use File::Copy;
use Module::Load;
use Error  qw(try finally except otherwise);
use Xperior::Xception;

extends 'Xperior::Executor::Base';

has DEFAULT_POLL => ( is => 'ro', default => 5 );
has PASSED       => ( is => 'ro', default => 0 );
has SKIPPED      => ( is => 'ro', default => 1 );
has FAILED       => ( is => 'ro', default => 10 );
has NOTSET       => ( is => 'ro', default => 100 );    #also failed

has 'reason' => ( is => 'rw' );

=head3  execute

Function which called via main xperior run cycle.

Internally it implement series of calls of scenarios
(see L<SimpleTest.pm> and inheritors as example)

    ${call_name_from_testds}__prepare
    ${call_name_from_testds}
    ${call_name_from_testds}__cleanup

For simplifying error reporting it's suggested to use exception via
B<Error  qw(try finally except otherwise)> and L<Xperior::Xception.pm>

Decision about error (high-priority falure) done via I<$self->errorcount>

Decision about failure  done via I<$self->failcount>

=cut

sub execute {
    my $self    = shift;
    my $class = $self->test->getParam('class');
    DEBUG "Create test class [$class]";
    load $class;
    my $test = $class->new;
    $self->addYE('class_version',$test->VERSION);
    my $method = $self->test->getParam('scenario');
    $test->executor($self);
    $test->testds($self->test);
    DEBUG 'Call method [$method]';
    try{
        #calling CTAPI::CastorTest::prepare_env or
        # it's inheritor threre. this often hidden call
        # should prepare main env vars for tests
        my $prepareenvptr = "prepare_env";
        if($test->can($prepareenvptr)){
            INFO "Calling [$prepareenvptr] for test";
            $test->$prepareenvptr($self);
        }

        my $prepareptr = "${method}__prepare";
        if($test->can($prepareptr)){
            INFO "Calling prepare for test [$method]";
            $test->$prepareptr($self);
        }
        $test->$method($self);
        INFO "Test [$method] passed";

    }catch TestFailed Error::subs::with{
        INFO "Test [$method] failed";
    }catch TestError Error::subs::with{
        INFO "Test [$method] failed with error";
    }finally{
        my $cleanupenvptr = "cleanup_env";
        if($test->can($cleanupenvptr)){
            INFO "Calling [$cleanupenvptr] for test";
            $test->$cleanupenvptr($self);
        }

        my $cleanupptr = "${method}__cleanup";
        if($test->can($cleanupptr)){
            INFO "Calling cleanup for test [$cleanupptr]";
            $test->$cleanupptr($self);
        }
    };
    $self->addYE( 'completed', 'yes' );
    if($test->errorcount() > 0) {
        $self->fail( $test->reason() );
    } elsif ( $test->failcount() > 0) {
        $self->fail( $test->reason() );
    }else{
         $self->pass();
    }
    $self->test->results( $self->yaml );
    return;
}

sub processSystemLog{
    my ( $self, $connector, $filename ) = @_;
    #processSystemLog is not implemented
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

