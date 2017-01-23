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
https://www.kernel.org/doc/Documentation/networking/netconsole.txt

This module starts local UDP server and receiving messages from nodes.
Message are sorting by source IP or DNS name and saved in log files.

Netconsole could be configured
    * statically, via option in boot cmd,
      e.g. linux ... netconsole=@192.168.200.102/eth1,5555@192.168.200.1/
    * dynamically via modprobe,
      e.g. modprobe netconsole netconsole=@192.168.200.102/eth1,5555@192.168.200.1/
    * dynamically via /sys/kernel/config/netconsole/

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
use Socket;
use Log::Log4perl qw(:easy);

use Xperior::Utils;

my $ENDMSG = "__NETCONSOLE_COLLECTION_END__";
my $title ='NetconsoleCollector';
has executeutils  => ( is => 'rw');
has udpserverthr => ( is => 'rw' );
has udpserver    => ( is => 'rw' );
has logs         => ( is => 'rw' );
has namecache    => ( is => 'rw' );
has netconsole_nodes => ( is => 'rw');
has maxlen => ( is => 'rw', default => 1024 );
=head2 Fields

Fields naming keep netconsole configfs options convetions.
Be aware, it is contradic to xperior point of view, because
in netconsole logic remote is log receiver (xperior) and local
is log sender (where netconsole is executed)

=head3  _autoconfigure::netconsole_local_ip

B< _autoconfigure::netconsole_local_ip> should be set to remote
node IP which is used for sending data

=cut

=head3 _autoconfigure::netconsole_local_interface>

B<_autoconfigure::netconsole_local_interface> should be set
to interface (e.g. eth1) which is used for sending data.
Important only for multi-interface setups.

=cut

=head3 netconsole_remote_ip

B<netconsole_remote_ip> should be set to IP which is used for
receiving data (where xperior is executed)

=cut

has netconsole_remote_ip  => ( is => 'rw', default => '' );

=head3 netconsole_remote_port

B<netconsole_remote_port> which is used for accepting data from
remote netconsole, one port per one xperior instance, every xperior
on one node should use unique port, default is 5555

=cut

has netconsole_remote_port => ( is => 'rw', default => '' );
has netconsole_remote_port_default => ( is => 'ro', default => 5555 );

=head3 netconsole_remote_mac

B<netconsole_remote_mac> which is used for accepting data from
remote netconsole. I<Since netconsole needs to work in as many
situations as possible (think of kernel bugs), it does not do
DNS or even ARP resolution, so we need to hardcode the IP and
MAC addresses we want to use. Note that if you are logging to a
server which is not in the same subnet as yours, you’ll need to
specify the MAC address of the gateway. You can get the MAC
address of your gateway using these commands:>

    GATEWAY=$(ip -4 -o route get 203.0.113.2 | cut -f 3 -d ' ')
    MAC=$(ip -4 neigh show $GATEWAY | cut -f 5 -d ' ')


=cut

has netconsole_remote_mac  => ( is => 'rw', default => '' );


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
    DEBUG "Awaiting UDP messages on port " .
            $self->netconsole_remote_port() . "\n";
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
            foreach my $f (values %{ $self->logs }){
                close $f;
            }
            last;
        }
        else {
            $self->_appendLog( $message, $host );
        }
    }
    return 1;
}

sub _autoconfigure{
    my ($self, $n) = @_;
    my  $ssh = $n->getRemoteConnector();

    my $netconsole_local_ip   = $n->{_node}->{netconsole_local_ip} || '';
    my $netconsole_local_interface =
            $n->{_node}->{netconsole_local_interface} || '';

    if( !$self->netconsole_remote_port()){
        my $port = $n->{_node}->{netconsole_remote_port} ||
                $self->netconsole_remote_port_default;
        $self->netconsole_remote_port($port);
    }
    #Set the level at which printing of messages is done to the console.
    $ssh->run('dmesg -n 8');
    my $lsmod = $ssh->run ('lsmod',10);
    #DEBUG Dumper $lsmod;
    if(!grep{/^netconsole.*/} split(/\n/x,$lsmod->{stdout})){
        DEBUG 'Module is not loaded, loading it';

        if(!$netconsole_local_ip){
            $netconsole_local_ip = inet_ntoa(inet_aton($n->ip()));
        }

        if(!$self->netconsole_remote_ip()){
            if($n->{_node}->{netconsole_remote_ip}){
                $self->netconsole_remote_ip(
                    $n->{_node}->{netconsole_remote_ip});
            }else{
                my $cmd = "ip -o route get ${netconsole_local_ip}";
                DEBUG "Executing '$cmd'";
                my $route = `$cmd`;
                if($route =~ m/src\s+([\d\.]+)\s+\\/x){
                    $self->netconsole_remote_ip($1);
                }else{
                    ERROR 'Cannot parse output ['. $route.
                        "]from cmd [$cmd]";
                    confess 'Cannot autodetect netconsole '.
                    'receiver ip';
                }
            }
        }

        if(!$self->netconsole_remote_mac()){
            if($n->{_node}->{netconsole_remote_mac}){
                $self->netconsole_remote_mac(
                    $n->{_node}->{netconsole_remote_mac});
            }else{
                my $target_ip =$self->netconsole_remote_ip();
                my $route = $ssh->run('ip -o route get '.
                        $self->netconsole_remote_ip())->{stdout};
                if($route =~ m/via\s+([\d\.]+)\s+dev/x){
                    DEBUG "Found gatevay:". $1;
                    $target_ip = $1;
                }else{
                    DEBUG 'No route found, use remote_ip';
                }
                my @arp = split('\n', $ssh->run('arp -n '.$target_ip)->{stdout});
                if($arp[2] =~ m/ether\s+([\da-f\:]+)\s+C/x){
                    $self->netconsole_remote_mac($1)
                }else{
                    ERROR 'No mac parsed, ignore it.'.
                    ' Netconsole possibile is not working';
                }
            }
        }

        my $cmd = 'modprobe netconsole netconsole="@'.
             $netconsole_local_ip.'/'.
             $netconsole_local_interface.','.
             $self->netconsole_remote_port().'@'.
             $self->netconsole_remote_ip().'/'.
             $self->netconsole_remote_mac().'"';
        DEBUG "modprobe cmd is [$cmd]";
        my $lm = $ssh->run($cmd);
        if( $lm->{exitcode} != 0 ){
            ERROR 'Cannot load netconsole module:'.
                $lm->{stderr};
            ERROR 'We do not exit there but netconsole it not workig.';
            $self->addMessage("Netconsole initialization failed on ".
                              "[$n->{id}] via command [$cmd]");
            $self->addMessage("Netconsole error[".$lm->{stderr}."]");
        }else{
            DEBUG 'Netconsole initialized';
            $self->addMessage("Netconsole is initialized on node ".
                              "[$n->{id}] via command [$cmd]");
            return $cmd;
        }
    }else{
        INFO 'Netconsole alredy loaded,'.
                ' suppose it is alredy configured';
        $self->addMessage("Netconsole is alredy configured, don't touch it");
    }
    return ;
}

before 'execute' => sub {
    my $self = shift;
    my @netconsole_nodes;
    $self->beforeBeforeExecute($title);
    #TODO check remote port aviability there
    #dynamic netcosole configuration
    foreach my $n ( @{ $self->env->nodes } ) {
        DEBUG Dumper  $n->ip();
        #TODO $n->_node->{netconsole} should autoset field of node
        if( $n->_node->{netconsole}){
            if($n->_node->{netconsole_autoconfig} &&
                $n->_node->{netconsole_autoconfig} eq 'yes'){
                DEBUG "Autoconfiguring node ". $n->ip();
                $self->_autoconfigure($n);
            }
            push @netconsole_nodes, $n;
        }else{
            DEBUG "No netconsole defined for node  ${n}->id() ";
        }
    }
    my $udpserver = IO::Socket::INET->new(
        LocalPort => $self->netconsole_remote_port(),
        Proto     => "udp"
    ) or confess "Couldn't bind to port " .
            $self->netconsole_remote_port() . " : $@\n";
    $self->namecache({});
    $self->udpserver($udpserver);
    DEBUG "Netconsole collector bound on port [" .
            $self->netconsole_remote_port() . "] \n";
    $self->addMessage( "Netconsole collector bind on port " .
            $self->netconsole_remote_port() );
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
    $self->afterBeforeExecute($title);
};

after 'execute' => sub {
    my $self = shift;
    $self->beforeAfterExecute($title);
    my $udpclient = IO::Socket::INET->new(
        PeerPort => $self->netconsole_remote_port(),
        PeerAddr => '127.0.0.1',
        Proto    => "udp"
      )
      or confess "Couldn't connect to remote port [127.0.0.1]["
      . $self->netconsole_remote_port()
      . "] : $@\n";
    $udpclient->send($ENDMSG);
    sleep 1; #give a chance for correct closing receiving thread
    if($self->udpserverthr->is_joinable()){
        $self->udpserverthr->join();
    }else{
        DEBUG 'udpserverthr alredy joined';
    }
    $self->udpserver->close() or confess "Cannot close server socket: $!";
    $self->afterAfterExecute($title);
};

1;
