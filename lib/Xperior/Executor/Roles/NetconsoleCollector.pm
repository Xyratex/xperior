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

Xperior::Executor::Roles::NetconsoleCollector - Extensions for collecting log from remote nodes.

=head1 DESCRIPTION
Technology description could be seen there:
http://wiki.lustre.org/index.php/Netconsole

This module starts local UDP server and receiving messages from nodes.
Message are sorting by source IP or DNS name and saved in log files.

=cut

package Xperior::Executor::Roles::NetconsoleCollector;

use strict;
use warnings;
use threads (
    'yield',
    'stack_size' => 64 * 4096,
    'exit'       => 'threads_only',
    'stringify'
);
use Moose::Role;
use Data::Dumper;
use IO::Socket;
use Log::Log4perl qw(:easy);

use Readonly;
Readonly my $ENDMSG => "__NETCONSOLE_COLLECTION_END__";

has udpserverthr => ( is => 'rw' );
has udpserver    => ( is => 'rw' );
has logs         => ( is => 'rw' );
has namecache    => ( is => 'rw' );

has port   => ( is => 'rw', default => 5555 );
has maxlen => ( is => 'rw', default => 1024 );

requires 'env', 'addMessage', 'getNormalizedLogName';

sub _appendLog {
    my ( $self, $message, $host ) = @_;
    my $targetfound = 0;
    foreach my $n ( @{ $self->env->nodes } ) {
        if ( defined($host) and ( ( $n->{ip} eq $host ) or ( $host eq '*' ) ) )
        {
            $targetfound++;
            my $fd = $self->logs->{ $n->id };
            print $fd $message, "\n";

            #DEBUG "Storing [$message][" . $n->id . "]";
            last unless $host eq '*';    #going over all nodes if '*'
        }
    }
    ERROR "Message from unknow node [$host] received [$message]"
      if $targetfound == 0;
    return;
}

sub _listen {
    my ( $self, $udpserver ) = @_;
    my $message = '';
    DEBUG "Awaiting UDP messages on port " . $self->port . "\n";
    while ( $udpserver->recv( $message, $self->maxlen ) ) {
        chomp $message;
        my ( $rport, $ipaddr ) = sockaddr_in( $udpserver->peername );
        my $host;
        if(defined($self->namecache->{$ipaddr})){
            $host = $self->namecache->{$ipaddr};
        }else{
            $host = gethostbyaddr( $ipaddr, AF_INET );
            if ( not defined($host) ) {
                $host = inet_ntoa($ipaddr);
                WARN "Cannot get name for [$host] :" . $?;
            }
            $self->namecache->{$ipaddr}=$host;
        }
        if ( $message eq $ENDMSG ) {
            DEBUG "Stopping Netconsole collecting";

            #append end for every registred log
            $self->_appendLog( 'Log collecting done', '*' );

            #close all logs files
            map { close $_ } ( values %{ $self->logs } );
            last;
        }
        else {
            $self->_appendLog( $message, $host );
        }
    }
    return 1;
}

before 'execute' => sub {
    my $self      = shift;
    my $udpserver = IO::Socket::INET->new(
        LocalPort => $self->port,
        Proto     => "udp"
    ) or confess "Couldn't bind to port " . $self->port . " : $@\n";
    $self->namecache({});
    $self->udpserver($udpserver);
    DEBUG "Netconsole collector bound on port " . $self->port . " \n";
    $self->addMessage( "Netconsole collector bind on port " . $self->port );
    $self->logs( {} );

    #initialise loggers
    foreach my $n ( @{ $self->env->nodes } ) {

        #TODO check netconsole for node?
        my $logdescr = $self->createLogFile( 'netconsole.' . $n->id );
        $self->logs->{ $n->id } = $logdescr;
    }

    $self->udpserverthr( threads->create( '_listen', ( $self, $udpserver ) ) );
    DEBUG "Thread started:" . $self->udpserverthr;
    sleep 1;    #to be sure that we bind before test started 
                #and may be get messages before test
};

after 'execute' => sub {
    my $self      = shift;
    my $udpclient = IO::Socket::INET->new(
        PeerPort => $self->port,
        PeerAddr => '127.0.0.1',
        Proto    => "udp"
      )
      or confess "Couldn't connect to remote port [127.0.0.1]["
      . $self->port
      . "] : $@\n";
    $udpclient->send($ENDMSG);
    $self->udpserverthr->join();
    $self->udpserver->close() or confess "Cannot close server socket: $!";
};

1;
