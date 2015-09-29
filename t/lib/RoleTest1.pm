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
# Please  visit http://www.xyratex.com/contact if you need additional information or
# have any questions.
#
# GPL HEADER END
#
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#
package RoleTest1;
use namespace::autoclean;
use strict;
use warnings;
use Xperior::SshProcess;
use Moose::Role;
use Log::Log4perl qw(:easy);

has 'rt1_testvar'  => ( is => 'rw', default => 102);
has 'rt1_groupvar' => ( is => 'rw', default => 104);
has 'commonvar'    => ( is => 'rw', default => 106);

my $title = 'RoleTest1';
our $test_sleep_time_before_role1 =6;
our $test_sleep_time_after_role1  =5;
our @EXPORT = qw($test_sleep_time_after_role1 $test_sleep_time_before_role1);

before 'execute' => sub {
    my $self = shift;
    $self->beforeBeforeExecute($title);
    DEBUG 'Role1::Do before';
    sleep($test_sleep_time_before_role1);
    $self->afterBeforeExecute($title);
};

after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    DEBUG 'Role1::Do after';
    sleep($test_sleep_time_after_role1);
    $self->afterAfterExecute($title);
};

sub rt1_printvars{
    my $self = shift;
    print "rt1_testvar=[".$self->rt1_testvar ."]\n";
    print "rt1_testvar=[".$self->rt1_groupvar ."]\n";
    print "commonvar=[".$self->commonvar ."]\n";
}

sub rt1_get_testvar{
    my $self = shift;
    return $self->rt1_testvar();
}

sub rt1_get_groupvar{
    my $self = shift;
    return $self->rt1_groupvar();
}

sub rt1_get_commonvar{
    my $self = shift;
    return $self->commonvar();
}


1;
