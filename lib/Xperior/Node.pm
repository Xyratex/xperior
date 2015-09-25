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

Xperior::Node - Node  abstraction

=head1 DESCRIPTION

Node  abstraction. Allows to get info about node.
Class implements different functions to work with node and get information about them.

=cut


package Xperior::Node;
use Moose;
#TODO enable after adding  package to common setup
#use namespace::autoclean;
use Error  qw(try finally except otherwise);
use Moose::Util::TypeConstraints;
use POSIX;
use Net::Ping;
use Log::Log4perl qw(:easy);

use Xperior::Utils;
use Xperior::SshProcess;
use Xperior::Nodes::KVMNode;
use Xperior::Nodes::BasicNode;
use Xperior::Nodes::IPMINode;


use constant DEFAULT_PROTO     => 'ssh';
use constant DEFAULT_NODE      => 'BasicNode';
use constant DEFAULT_UP_TIME_SEC   =>  300; #sec

=head2 Public fields and supported constructor parameters

=head3 isReachable

check that node is reachable via ssh (pdsh - TBI), and Lustre basic liveness (Lustre is up and files can be created).

=cut

has 'ctrlproto'    => ( is => 'rw' );
has 'user'         => ( is => 'rw' );
has 'pass'         => ( is => 'rw' );
has 'ip'           => ( is => 'rw' );
has 'port'         => ( is => 'rw' );
has 'id'           => ( is => 'rw' );
has 'console'      => ( is => 'rw' );
has 'bridge'       => ( is => 'rw' );
has 'bridgeuser'   => ( is => 'rw', default =>'root' );
has 'nodetype'     => ( is => 'rw' );
has 'pingport'     => ( is => 'rw', default =>22 );

#has '_ssh'         => ( is => 'rw'); # isa => 'Xperior::SshProcess');
has '_pinger'      => ( is => 'rw', isa => 'Net::Ping');
has '_node'        => ( is => 'rw' );

#machined/os static info
has 'architecture'    => ( is => 'rw');
has 'os'              => ( is => 'rw');
has 'os_release'      => ( is => 'rw');
has 'os_distribution' => ( is => 'rw');
has 'lustre_version'  => ( is => 'rw');
has 'lustre_net'      => ( is => 'rw');

#mem/disk info
has 'memtotal'        => ( is => 'rw');
has 'memfree'         => ( is => 'rw');
has 'swaptotal'       => ( is => 'rw');
has 'swapfree'        => ( is => 'rw');

has 'rconnector'   => (
                        is => 'rw',
                        default => undef
                    );
has 'crashdir'     => (
                        is => 'ro',
                        default => '/var/crash/',
                        isa => 'Str'
                    );

has 'ismpdready'   => ( is => 'rw',
                        default => undef
                    );

sub BUILD {
    my $self   = shift;
    my $params = shift;
    $self->ctrlproto(DEFAULT_PROTO)
                unless defined $self->ctrlproto;
    $self->nodetype(DEFAULT_NODE)
                        unless defined $self->nodetype;

    DEBUG "Apply role [".$self->nodetype."]";
    if($self->nodetype eq 'KVMNode'){
        Xperior::Nodes::KVMNode->meta->apply($self);
        $self->kvmdomain($params->{'kvmdomain'});
        $self->kvmimage($params->{'kvmimage'});
        $self->restoretimeout( $params->{'restoretimeout'})
            if defined $params ->{'restoretimeout'};

    }elsif($self->nodetype eq 'BasicNode'){
        Xperior::Nodes::BasicNode->meta->apply($self);
    }elsif($self->nodetype eq 'IPMINode'){
        Xperior::Nodes::IPMINode->meta->apply($self);
        $self->ipmi($params->{'ipmi'});
        $self->ipmidrv($params->{'ipmidrv'})
                if defined $params->{'ipmidrv'};
        $self->ipmiuser($params->{'ipmiuser'})
                if defined $params->{'ipmiuser'};
        $self->ipmipass($params->{'ipmipass'})
                if defined $params->{'ipmipass'};
    }else{
        confess "Cannot find nodetype [".$self->nodetype."]";
    }
}

=head3 isReachable

check that node is reachable via ssh (pdsh - TBI), and Lustre basic
liveness (Lustre is up and files can be created).

=cut


sub isReachable{
    my $self = shift;
    #TODO only ssh now is supported
    my $c;
    eval{
        $c = $self->getRemoteConnector();
    };
    unless ( defined ($c)){
        WARN "Cannot ssh host [".$self->id."]";
        return 0;
    }else{
        DEBUG $self->id ." is reachable ";
        return 1;
    }
}

sub getConfig{
    my $self = shift;
    my $sc = $self->getRemoteConnector;
    $self->architecture(trim($sc->createSync('uname -m')));
    $self->os(trim($sc->createSync('uname -o')));
    $self->os_release(
            trim(
                (split(':\s',$sc->createSync('lsb_release -r')))
                [1]
                ));

    $self->os_distribution(
            trim(
                (split(':\s',$sc->createSync('lsb_release -d')))
                [1]
                ));

    $self->lustre_version(
            trim(
                (split('\s', $sc->createSync('lctl lustre_build_version')))
                    [2] ));
    $self->lustre_net(
            trim(
                (split('@', $sc->createSync('lctl list_nids ')))
                    [1] ));

    my $memout = $sc->createSync('cat /proc/meminfo');
    foreach my $s ( split('\n',$memout)){
        if( $s =~ m/MemTotal:\s+(\d+)/){
            $self->memtotal($1);
        }
        if( $s =~ m/MemFree:\s+(\d+)/){
            $self->memfree($1);
        }
        if( $s =~ m/SwapTotal:\s+(\d+)/){
            $self->swaptotal($1);
        }
        if( $s =~ m/SwapFree:\s+(\d+)/){
            $self->swapfree($1);
        }
    }

    #TODO add CPU processor count
    #my $cpuout = $sc->createSync('cat /proc/cpuinfo');
    return;
}

sub getLFFreeSpace{
    my $self = shift;
    my $sc =$self->getRemoteConnector;
    my $cmd = $sc->createSync("lfs df");
    foreach my $str ( split(/\n/,$cmd)){
        return $1
            if( $str =~ m/filesystem\ssummary\:\s+\d+\s+\d+\s+(\d+)/ );
    }
    DEBUG "getLFFreeSpace -  cannot parse:[$cmd]";
    return -1;
}

sub getLFFreeInodes{
    my $self = shift;
    my $sc =$self->getRemoteConnector;
    my $cmd = $sc->createSync("lfs df -i");
    foreach my $str ( split(/\n/,$cmd)){
        return $1
            if( $str =~ m/filesystem\ssummary\:\s+\d+\s+\d+\s+(\d+)/ );
    }
    DEBUG "getLFFreeInodes -  cannot parse:[$cmd]";
    return -1;
}

sub getLFCapacity{
    my $self = shift;
    my $sc =$self->getRemoteConnector;
    my $cmd = $sc->createSync("lfs df");
    foreach my $str ( split(/\n/,$cmd)){
        return $1
            if( $str =~ m/filesystem\ssummary\:\s+(\d+)\s+\d+\s+\d+/ );
    }
    DEBUG "getLFCapacity -  cannot parse:[$cmd]";
    return -1;

}

=head3 run(cmd,timeout)

Execute command on node which associated with object.

Function throws execption if ssh problem detected

=cut

#TODO add test on it
sub run
{
    my ( $self, $cmd, $timeout ) = @_;
    my $ssh = $self->getExclusiveRC;
    throw NullObjectException
        ("Cannot create ssh object")
            unless defined $ssh;
    DEBUG $ssh->createSync($cmd, $timeout);
    throw CannotConnectException
        ("Cannot execute command on remote side")
            unless defined  $ssh->syncexitcode;
    return $ssh->syncexitcode;
}

=head3 getFile(src,dst)

Get file from node which associated with object.

Return Xperior::SshProcess->getFile exit code
Return 0 if file copied and exit code if error occurred.


=cut

#TODO add test on it
sub getFile
{
    my ($self, $src, $dst) = @_;
    my $ssh = $self->getRemoteConnector;
    return 254 unless defined $ssh;
    return $ssh->getFile($src,$dst);
}

=head3 getRemoteConnector

Return connector for node. This connector is the main node connector and should
be used for short (synchronous) execution and main single execution for avoid
memory wasting. If consumer need more then one long a synchronous execution
next connector can be get via connector clone or via getUncontrolledRC

=cut

sub getRemoteConnector{
    my $self = shift;
    return $self->rconnector
         if defined $self->rconnector;

    my $sc = Xperior::SshProcess->new();

    if ($sc->init($self) < 0){
        $self->rconnector(undef);
        return undef;
    }

    $self->rconnector($sc);
    return $sc;
}

=head3 getExclusiveRC

Return a connector which can be used exclusively by consumer. Nobody more can
get it.

=cut

sub getExclusiveRC{
    my $self = shift;
    my $rc = $self->getRemoteConnector() || return;
    my $urc = $rc->clone();
    $urc->initTemp;
    return $urc;
}

=head3 storeKernelDump($file)

Store kernel crash dump core in file which pointed.

Paramaters:

$file - file which where will store vmcore file.

Return 0 if file copied, -1 if no dump files found and exit code if error occurred.

=cut

sub storeKernelDump {
    my ($self, $storefile) = @_;
    my $rc = $self->getRemoteConnector;
    return -2 unless defined $rc ;
    my @found = grep (/vmcore/, split(/\n/,$rc->createSync("find  ".$self->crashdir,10)));
    my $kdump=undef;
    if(scalar(@found) eq 1){
        $kdump = $found[0];
    }elsif(scalar(@found) > 1){
        WARN "More then one kernel dump found, selecting last by directory name date";
        INFO "Please use Node->cleanCrashDir for reliable results";
        my @sorted =  sort {$b cmp $a} @found;
        $kdump = $sorted[0];
    }else{
        ERROR "No kernel dump found at host: [".$self->ip."]";
        return -1;
    }
    DEBUG "Found kernel dump file:[".$kdump."]";
    return $rc->getFile($kdump,$storefile);
}

=head3 cleanCrashDir

Remove all previosly stored kernel dumpes on local filesytems on remote node
Return remote command exit code.

=cut

sub cleanCrashDir{
    my ($self) = @_;
    my $rc = $self->getRemoteConnector;
    DEBUG "Crashdir is [". $self->crashdir."]";
    confess "Crashdir is not set" unless(
                              (defined($self->crashdir))and
                              ($self->crashdir ne '') and
                              ($self->crashdir ne '/'));
    my $res = $rc->createSync("rm -rf  ".$self->crashdir."/*");
    ERROR "Cannot remove dump files:".$res
                    if( $rc->syncexitcode != 0);
    return $rc->syncexitcode;
}

=head3 waitDown($timeout)

default timeout is 300 sec

Exit code:

0 - host is down until timeout is exceed

1 - host is up after timeout


=cut

sub waitDown{
    my ($self,$timeout) = @_;
    my $starttime = time;
    $timeout = 300 unless defined $timeout;
    #mean wait while kore dumped
    while(( $starttime + $timeout ) > time ){
        unless($self->isAlive){
            last;
            DEBUG "Host is down";
            return 0;
        }
        sleep 10;
    }
    ERROR "System still up";
    return 1;
}

=head3 waitUp($timeout)

Wait until node up (available via ssh) and set ssh member, return ssh object.
If node is not up until $timeout or ssh connection failed return undef.

=cut

sub waitUp {
    my ($self, $timeout) = @_;
    $timeout = DEFAULT_UP_TIME_SEC unless defined $timeout;
    $self->rconnector($self->_waitForNodeUp( $self->ip,$self->user, $timeout ));
    return $self->rconnector;
}


=head3 ping

Ping node.

Returns a success flag. If the hostname cannot be found or there
is a problem with the IP number, the success flag returned will
be undef. Otherwise, the success flag will be 1 if the host is
reachable and 0 if it is not.

=cut

sub ping {
    my $self = shift;
    confess "Incorrect port set for node ".$self->id()
                                unless(isdigit $self->pingport());

    if((isdigit $self->pingport())
                and ($self->pingport() == 0)){
        return 1;
    }

    if( not defined $self->_pinger){
        if(($self->pingport() > 0)
            and ($self->pingport() <65535)){
            $self->_pinger(Net::Ping->new('tcp',15));
            $self->_pinger->port_number($self->pingport());
            DEBUG "Set ping port to ".$self->pingport();
        }else{
            confess "Port out of range"
            . $self->pingport()
            ." for node ".$self->id();
        }
    }
    DEBUG "Ping host [".$self->{ip}."]";
    return $self->_pinger->ping($self->ip);
}

sub _waitForNodeUp {
    my ($self, $node, $user, $timeout ) = @_;
    my $sp;
    my $up = 0;
    my $starttime = time;
    my $p = Net::Ping->new();
    INFO "Wait until node [$node] up";

    while ( ( $starttime + $timeout ) > time ) {
        if ( $self->ping ) {
            INFO "host is alive, check ssh\n";
            $sp = Xperior::SshProcess->new();
            my $ss = $sp->init( $node, $user, 22, 1 );
            if ( $ss == 0 ) {
                INFO "ssh is up\n";
                $up = 1;
                last;
            }
            else {
                ERROR "ssh is down,wait.\n";
            }
        }
        else {
            ERROR "host is unreachable,wait.\n";
        }
        sleep 15;
    }
    unless ($up) {
        WARN "Node is not up in [".(time - $starttime)."] sec";
        return undef;
    }
    return $sp;
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

