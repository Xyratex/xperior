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
# Copyright 2017 Seagate
#
# Author: Roman Grigoryev<roman.grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Nodes::KVMNode - KVM node extension

=head1 DESCRIPTION

For work it needed ec2-api-tools.zip from
http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
dowloaded and nextracted to dir.
Path dir should be set $self->'ec2_home'.
Path to JRE or JSDK dir should be set to $self->'java_home'

=head1 METHODS

=cut


package Xperior::Nodes::EC2Node;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);
use File::chdir;
use File::Copy;
use Exporter;
use Carp;
use Error qw(try finally except otherwise);
use List::Util qw(min max);
use Proc::Simple;
use Data::Dumper;
use AWS::CLIWrapper;




use Xperior::SshProcess;
use Xperior::Utils;
use Xperior::Xception;
use Xperior::Utils;
use Moose::Role;
with qw( Xperior::Nodes::NodeManager );


has 'access_key' => ( is => 'rw' );
has 'secret_key' => ( is => 'rw' );
has 'ami'        => ( is => 'rw', isa => 'Str' );

has 'sleep_after_stop' => ( is => 'rw', isa => 'Int', default => 300); #sec
has 'sleep_after_start'   => ( is => 'rw', isa => 'Int', default => 300); #sec
has 'sleep_atom'   => ( is => 'rw', isa => 'Int', default => 5); #sec

has 'instance'                 => ( is => 'rw' );
has '_aws'                     => ( is => 'rw' );
has '_status_code'             => ( is => 'rw' );
has 'public_ip'                => ( is => 'rw' );
has 'private_ip'               => ( is => 'rw' );
has '_latest_running_instance' => ( is => 'rw');



sub init {
    my $self = shift;
    if ( ( ! $self->access_key() ) or ( ! $self->secret_key() ) ){
        DEBUG "access_key or/and secret_key is not set " ;
    }
    DEBUG "Initializing";

    my $aws = AWS::CLIWrapper->new(
        region => 'us-east-2',
    );
    $self->_aws( $aws );
    if( $self->instance() ) {
        my $res = $aws->ec2(
            'describe-instances' => { instance_ids => [ $self->instance() ] },
        );
        DEBUG "running_instances: ". Dumper $res;
    } else {
        confess "Instance creating is not impelement";
    }
    #DEBUG Dumper $aws;

}

sub sync{
    my $self = shift;
    sleep max( $self->sleep_after_stop(),
                $self->sleep_after_start() );
}


=head3

Based on call
          o instance-state-code - The code for the instance state, as a 16-bit
            unsigned  integer.  The  high byte is an opaque internal value and
            should be ignored. The low byte is set based on the  state  repre-
            sented.  The valid values are 0 (pending), 16 (running), 32 (shut-
            ting-down), 48 (terminated), 64 (stopping), and 80 (stopped)

interprete only 16  as alive

return 1 if alive, 0 in other cases

=cut

sub isAlive {
    my $self = shift;
    my $res = $self->_awsDo('describe-instances', { instance_ids => [ $self->instance() ] });
    my $status = 0;
    #DEBUG Dumper $res;
    if ($res) {
        for my $res ( @{ $res->{Reservations} }) {
            for my $is (@{ $res->{Instances} }) {
                DEBUG "AWS status      is [". $is->{State}->{Name}."]\n";
                DEBUG "AWS status code is [". $is->{State}->{Code}."]\n";
                $self->_status_code($is->{State}->{Code});
                if( $is->{State}->{Code} == 16 ) {
                    $status = 1;
                    $self->public_ip ( $is->{PublicIpAddress} );
                    $self->ip( $self->public_ip() );
                    $self->private_ip( $is->{PrivateIpAddress} );
                    $self->_latest_running_instance( $is );
                }
                last; #process only first element
            }
            last; #process only first element
        }
    }
    return $status;
}

=head3


if $force == true - use force 'halt' with probably fs crash

return state if new state is not 16 or 0
return 0  in other cases

=cut

sub halt {
    my ( $self, $force ) = @_;
    INFO "Stopping" . $self->instance;

    my $res;
    if ( $force ) {
        DEBUG "Do aws vm stop with force";
        $res = $self->_awsDo( 'stop-instances',
            { instance_ids => [ $self->instance() ],
                force        => $AWS::CLIWrapper::true,
            }, );
    } else {
        DEBUG "Do aws vm stop";
        $res = $self->_awsDo( 'stop-instances',
            { instance_ids => [ $self->instance() ] } );

    }
    #
    #TODO probably we should wait end of shutdown via regular status call
    #TODO probably we should check current state for check applicability
    #
    my $cur_state = $res->{StoppingInstances}->[0]->{CurrentState}->{Code};
    DEBUG Dumper $res;
    DEBUG "After stop cmd switch from [".
            $res->{StoppingInstances}->[0]->{PreviousState}->{Name}.
            "] to [".
            $res->{StoppingInstances}->[0]->{CurrentState}->{Name}."]";
    if ( ( $cur_state != 0 ) and ( $cur_state != 16 ) ){
        return $cur_state;
    }
    return 0;
}

sub restoreSystem{
    confess "restoreSystem is not implemented";
}

=head3

return 1  if started and in "pending state"
return -1 if instance started before call
return -2 if not in stopped state until timeout
return -3 if instance terminated
return 0  in other cases

=cut

sub start {
    my ($self) = @_;
    $self->isAlive();
    if( $self->_status_code() == 16 ){
        INFO "Instance already started";
        return -1;
    } elsif ( $self->_status_code() == 48 ) {
        INFO "Instance terminated";
        return -3;
    } elsif ( $self->_status_code() != 80) {
        my $time = time();
        my $stopped = 0;
        while ( ( $time+$self->sleep_after_stop() ) < time() ){
            $self->isAlive();
            if( $self->_status_code() == 80 ){
                $stopped = 1;
                last;
            }
            sleep $self->sleep_atom();
        }
        if( not $stopped){
            INFO "Instance is not stopped in timeout:" .
                        $self->sleep_after_stop();
            INFO "Current status is:" . $self->_status_code();
            return -2;
        }
    }
    INFO "Starting " . $self->instance();
    my $res = $self->_awsDo('start-instances',
                        { instance_ids => [ $self->instance() ] });

    DEBUG Dumper $res;
    DEBUG "After start cmd switched  from [".
            $res->{StartingInstances}->[0]->{PreviousState}->{Name}.
            "] to [".
            $res->{StartingInstances}->[0]->{CurrentState}->{Name}."]";
    if( $res->{StartingInstances}->[0]->{CurrentState}->{Code} == 0 ) {
        INFO "Instance started";
        return 1;
    }
    return 0;
}


sub _awsDo {
    my ($self, $cmd, $params) = @_;
    my $res = $self->_aws()->ec2( $cmd => $params, );
    if ( ! $res ){
        DEBUG $AWS::CLIWrapper::Error->{Code};
        DEBUG $AWS::CLIWrapper::Error->{Message};

        throw NullObjectException(
            "Cannot execute command [".
                $cmd."] with message [".
                $AWS::CLIWrapper::Error->{Message}."]");
    }
    return $res;
}

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



Copyright 2017 Seagate

=head1 AUTHOR

Roman Grigoryev<roman.grigoryev@seagate.com>

=cut




