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
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#
package ExecutorNetconsoleTest;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Xperior::SshProcess;
use Moose;
extends 'Xperior::Executor::SingleProcessBase';
#my $serverhost='192.168.200.1 ';
#my $serverhost='172.16.30.18 ';
#my $serverport='5555';
sub execute {
    my $self= shift;
    my $serverhost = $self->netconsole_remote_ip();#'172.16.30.18 ';
    my $serverport = $self->netconsole_remote_port(); ##'5555';
    my $id   = $self->test->getParam('id');
    $self->fail;
    $self->addYE( 'testid',  $id );
    $self->addYE( 'message', 'ExecutorNetconsoleTest engine, empty test' );
    $self->pass;
    $self->test->results( $self->yaml );

    my $sp = Xperior::SshProcess->new();
    DEBUG '===Test1===';
    $sp->init( 'mds', 'root' );
    $sp->createSync(
    "echo \"===Test1===\" | /usr/bin/nc -u $serverhost $serverport -w 5", 10 );
    my $sp1 = Xperior::SshProcess->new();
    DEBUG '===Test2===';
    $sp1->init( 'lclient', 'root' );
    $sp1->createSync(
    "echo \"===Test2===\" | /usr/bin/nc -u $serverhost $serverport -w 5", 10 );

    $sp->createSync(
    "echo \"===Test3===\" | /usr/bin/nc -u $serverhost $serverport -w 5", 10);
    $sp1->createSync(
    "echo \"===Test4===\"  > /dev/kmsg"
    );
    sleep 5;
}

1;

