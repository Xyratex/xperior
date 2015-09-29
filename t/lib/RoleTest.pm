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
package RoleTest;
use namespace::autoclean;
use strict;
use warnings;
use Xperior::SshProcess;
use Moose::Role;
use Log::Log4perl qw(:easy);

#set of testing values
has 'rt_testvar'  => ( is => 'rw', default => 101);
has 'rt_groupvar' => ( is => 'rw', default => 103);
has 'commonvar'   => ( is => 'rw', default => 106);

my $title = 'RoleTest';
our $test_sleep_time_before = 1;
our $test_sleep_time_after  = 3;
our @EXPORT = qw($test_sleep_time_after $test_sleep_time_before);


before 'execute' => sub {
    my $self = shift;
    $self->beforeBeforeExecute($title);
    DEBUG 'Role::Do before';
    sleep($test_sleep_time_before);
    $self->afterBeforeExecute($title);
};

after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    DEBUG 'Role::Do after';
    sleep($test_sleep_time_after);
    $self->afterAfterExecute($title);
};

sub rt_printvars{
    my $self = shift;
    print "rt_testvar=[".$self->rt_testvar ."]\n";
    print "rt_testvar=[".$self->rt_groupvar ."]\n";
    print "commonvar=[".$self->commonvar ."]\n";
}

sub rt_get_testvar{
    my $self = shift;
    return $self->rt_testvar();
}

sub rt_get_groupvar{
    my $self = shift;
    return $self->rt_groupvar();
}

sub rt_get_commonvar{
    my $self = shift;
    return $self->commonvar();
}


1;
