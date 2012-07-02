#
#===============================================================================
#
#         FILE: KVMNode.pm
#
#  DESCRIPTION:
#
#       AUTHOR: ryg,kyr
# ORGANIZATION: Xyratex
#      CREATED: 06/29/2012 05:52:13 PM
#===============================================================================
package Xperior::Nodes::KVMNode;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use File::chdir;
use File::Copy;
use Exporter;
use Carp;
use Net::Ping;
use Error qw(:try);
use List::Util qw(min max);

use Xperior::SshProcess;
use Xperior::Utils;
use Xperior::Xception;

use Moose;

with qw( Xperior::Nodes::NodeManager );

has 'kvmdomain' => ( is => 'ro', isa => 'Str' );
has 'kvmimage'  => ( is => 'rw', isa => 'Str' );
has 'restoretimeout' => ( is => 'rw', isa => 'Int');

use constant SLEEP_AFTER_DESTROY         => 10;  #sec
use constant DEFAULT_RESTORE_TIMEOUT     => 700; #sec
use constant SLEEP_AFTER_START           => 15;  #sec
sub BUILD {
    my $self   = shift;
    my $params = shift;
    $self->restoretimeout(DEFAULT_RESTORE_TIMEOUT)
                unless defined $self->restoretimeout;
    DEBUG "Constructor params: $params->{kvmdomain}";
}

sub sync{
    sleep max(SLEEP_AFTER_DESTROY,  SLEEP_AFTER_START);
}

sub isAlive {
    my ($self) = @_;
    DEBUG "Check " . $self->kvmdomain;
    return $self->_isDomainActive( $self->kvmdomain );
}

sub halt {
    my ($self) = @_;
    return $self->_virshDo( 'destroy', $self->{kvmdomain} );
}

sub restoreSystem{
    my ($self, $image) = @_;
    $self->_virshDo('destroy', $self->kvmdomain);
    sleep SLEEP_AFTER_DESTROY;
    runEx("sudo rm -vf ".$self->kvmimage);
    runEx("sudo cp -v  $image ".$self->kvmimage);
    
    $self->start();
    sleep SLEEP_AFTER_START;

    throw KVMException("Node ".$self->kvmdomain." is not up\n")
        unless $self->waitUp($self->restoretimeout);

    DEBUG $self->_virshDo( 'dominfo', $self->kvmdomain );
}

sub start {
    my ($self) = @_;
    INFO "Starting " . $self->kvmdomain;
    $self->_virshDo( 'start', $self->kvmdomain );
}

#sub _restartLibvirt {
#    return runExternalApp( 'sudo /etc/init.d/libvirtd restart', 1 );
#}

sub _virshDo {
    my ( $self, $action, $vm ) = @_;
    my $attempt  = 0;     # current attempt
    my $result  = -1;    # result
    my $attempt_limit = 5;     # number of attempts, workaround for kvm problem
    while ( ( $attempt < $attempt_limit ) and ( $result != 0 ) ) {
        sleep $attempt;
        $result = runEx( "sudo virsh $action $vm", 0 );

        #runExternalApp( 'sudo virsh connect qemu:///system',0 );
        if (    ( $result != 0 )
            and ( $action ne 'start' )
            and ( $action ne 'destroy' ) )
        {

            #switch it off because migrate to new kvm version
            #restartLibvirt;
            WARN "Cannot do [$action] on [$vm]";
            $attempt++;
            next;
        }
        if ( $action eq 'start' ) {
            my $ls = $self->_isDomainActive($vm);
            if ( $ls == 1 ) {
                INFO "Domain started successfully";
                last;
            }
            WARN "Domain [$vm] was started but status is [$result]";
            $attempt++;
            next;
        }
        elsif ( $action eq 'destroy' ) {
            my $result = $self->_isDomainActive($vm);
            if ( $result == 0 ) {
                INFO "Domain destroyed successfully";
                last;
            }
            WARN "Domain [$vm] was destroyed but status is [$result]";
        }
        last;
    }
    unless ( $attempt < $attempt_limit ) {
        confess "Cannot complete [$action] for [$vm] in $attempt_limit attempts";
    }
}

sub _isDomainActive {
    my ( $self, $vm ) = @_;
    my @out = split( /\n/,`sudo virsh list --all`);
    my $lf  = 0;
    my @adomains;
    my @idomains;
    my $status = 1;
    foreach my $str ( @out ) {
        if ( $str =~ m/----------/ ) {
            $lf = 1;
            next;
        }
        if ($lf) {
            if ( $str =~ m/^\s*\d+\s+([\w\d]+)\s+/ ) {
                push @adomains, $1;
                if ( $vm eq $1 ) {
                    $status = 1;
                    INFO "[$vm] is active";
                }
            }

            if ( $str =~ m/^\s+\-\s+([\w\d]+)\s+/ ) {
                push @idomains, $1;
                if ( $vm eq $1 ) {
                    $status = 0;
                    INFO "[$vm] is inactive";
                }
            }

        }
    }
    DEBUG "Found active domains :" . join( ',', @adomains );
    DEBUG "Found inactive domains :" . join( ',', @idomains );
    return $status;
}


__PACKAGE__->meta->make_immutable;
1;
