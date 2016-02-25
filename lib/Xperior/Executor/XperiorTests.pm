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

Function execute process on TBD
=cut

sub execute {
    my $self    = shift;
    my $class = $self->test->getParam('class');
    DEBUG "Create test class [$class]";
    load $class;
    my $test = $class->new;
    my $method = $self->test->getParam('scenario');
    DEBUG 'Call method [$method]';
    try{
        $test->$method($self);
        INFO "Test [$method] passed";

    }catch TestFailed Error::subs::with{
        INFO "Test [$method] failed";
    }finally{

    };
    $self->addYE( 'completed', 'yes' );
    if($test->failcount > 0){
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

