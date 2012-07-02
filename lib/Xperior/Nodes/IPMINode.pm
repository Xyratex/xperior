#
#===============================================================================
#
#         FILE: IPMINode.pm
#
#  DESCRIPTION:
#
#       AUTHOR: ryg
# ORGANIZATION: Xyratex
#      CREATED: 06/30/2012 10:30:13 PM
#===============================================================================
package Xperior::Nodes::IPMINode;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use File::chdir;
use File::Copy;
use Exporter;
use Carp;
use Net::Ping;
use Error qw(:try);

use Xperior::SshProcess;
use Xperior::Utils;
use Xperior::Xception;

use Moose;

with qw( Xperior::Nodes::NodeManager );

has 'ipmi' => ( is => 'ro', isa => 'Str' );

use constant PMITERATIONS  => 5;    
use constant SLEEPAFTEROFF => 30;    #sec

sub sync{
    sleep SLEEPAFTEROFF;
}

sub isAlive {
    my ($self) = @_;
    DEBUG "Check " . $self->host;
    my $res = $self->_powermanDo('stat');
    return 1 if $res eq 'on';
    return 0;
}

sub halt {
    my ($self) = @_;
    DEBUG "Stopping host=" . $self->host . " ipmi=" . $self->ipmi;
    $self->_powermanDo('stop');
}

sub start {
    my ($self) = @_;
    DEBUG "Starting host=" . $self->host . " ipmi=" . $self->ipmi;

    #$self->getIpmiInfo;
    $self->_powermanDo('start');
}

sub restoreSystem {
    confess "restoreSystem is not implemented";
}

sub _powermanDo {
    my ( $self, $action ) = @_;
    my $i = 0;
    while ( $i < PMITERATIONS ) {
        $i++;
        if ( $action eq 'start' ) {
            my $oncmd =
                "/usr/sbin/ipmipower -h "
              . $self->ipmi . " "
              . "--username=admin --password=admin "
              . "--driver-type=lanplus --on ";
            my $onr = ` $oncmd `;
            chomp $onr;
            DEBUG "Exec result is [$onr]";
            next if $self->_isBMCError($onr);
            if ( $onr =~ m/\:\s+ok\s*$/ ) {
                INFO "Node [" . $self->host . "] started";
                return 0;
            }
            else {
                confess "Cannot power on node Node ["
                  . $self->host . "]:["
                  . $self->ipmi
                  . "]=[$onr]";
            }
        }
        elsif ( $action eq 'stat' ) {
            my $statcmd =
                "/usr/sbin/ipmipower -h "
              . $self->ipmi
              . " --username=admin --password=admin "
              . " --driver-type=lanplus --stat ";
            my $statr = ` $statcmd `;
            chomp $statr;
            DEBUG "Exec result is [$statr]";
            next if$self->_isBMCError($statr);
            if ( $statr =~ m/\:\s+on\s*$/ ) {
                INFO "Node [" . $self->host . "] on";
                return 'on';
            }
            elsif ( $statr =~ m/\:\s+off\s*$/ ) {
                INFO "Node [" . $self->host . "] off";
                return 'off';
            }
            else {
                confess "Cannot check power status for node ["
                  . $self->host . "]:["
                  . $self->ipmi
                  . "]=[$statr]";
            }

        }
        elsif ( $action eq 'stop' ) {
            my $offcmd =
                "/usr/sbin/ipmipower -h "
              . $self->ipmi
              . " --username=admin --password=admin "
              . " --driver-type=lanplus --off ";
            my $offr = ` $offcmd `;
            chomp $offr;
            DEBUG "Exec result is [$offr]";
            next if $self->_isBMCError($offr);
            if ( $offr =~ m/\:\s+ok\s*$/ ) {
                INFO "Node [" . $self->host . "] started";
                return 0;
            }
            else {
                confess "Cannot power down node Node ["
                  . $self->host . "]:["
                  . $self->ipmi
                  . "]=[$offr]";
            }
        }
        confess "No supported command found for action [$action]";
    }
    confess "Cannot do [$action] in [" . PMITERATIONS . "]";
}

sub _isBMCError {
    my ( $self, $out ) = @_;
    if (($out =~ m/BMC\serror/) or ($out =~ m/session timeout/)) {
        return 1;
    }
    return 0;
}

sub getIpmiInfo {
    my ($self) = shift;
    my $node   = $self->host;
    my $fru    = `ipmitool -A PASSWORD  -U admin -P admin  -H $node fru `;
    INFO "FRU info:\n$fru";

    my $cs =
      `ipmitool -A PASSWORD  -U admin -P admin  -H  $node chassis status `;
    INFO "Chassis Status:\n$cs";

    my $mcg = `ipmitool -A PASSWORD  -U admin -P admin  -H $node mc guid `;
    INFO "MC GUID:\n $mcg";
}

__PACKAGE__->meta->make_immutable;
1;
