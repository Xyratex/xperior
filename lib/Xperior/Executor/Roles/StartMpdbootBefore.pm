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
# Copyright
#       2012 Xyratex Technology Limited
#       2014 Seagate Technology
# Author:
#   Elena Gryaznova<Elena_Gryaznova@xyratex.com>
#   Roman Grigoryev<roman.grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::StartMpdbootBefore - Role define harvesting info from
master client host

=head1 DESCRIPTION

Role define starting mbdboot on master client before each suite.

=cut

package Xperior::Executor::Roles::StartMpdbootBefore;

use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use File::Slurp;
use File::Temp qw(:mktemp);

requires 'env';
has mpdpath         => ( is => 'rw', default => '');
has machinefile     => ( is => 'rw',
                            default => '/tmp/machinefile');

before 'execute' => sub {
    my $self = shift;
    my $mpdpath = $self->mpdpath();
    # nothing to do if mpdboot is properly started already
    my $master = $self->env->getNodeById
        ( $self->_getMasterNode->{'node'} );
    return if $master->ismpdready();

    # shutdown mpdboot on each client;
    # this guarantees that mpdboot is started
    # properly (i.e. only on master client)
    my @nodes = map { $_->{'node'} } @{ $self->env->getLustreClients()};
    my @ips;
    foreach my $id ( @nodes ) {
        my $c = $self->env->getNodeById( $id )->getRemoteConnector();
        my $res = $c->run(
            "sudo -u  mpiuser ${mpdpath}mpdallexit",
            timeout => 300 );
        DEBUG 'mpdallexit out:'.$res->{stdout};
        DEBUG 'mpdallexit err:'.$res->{stderr};
        push @ips, $self->env->getNodeById( $id )->ip();
    }
    # produce machinefile
    # my $machinefile = "/tmp/machinefile";
    my($fh, $tmp_file) = mkstemp( "/tmp/machinefile_XXXX" );
    close $fh;
    write_file ($tmp_file, join ( "\n", @ips ));
    chmod 0644, $tmp_file;
    my $not_copied = $master->getRemoteConnector()->putFile(
                                    $tmp_file, $self->machinefile());
    unlink $tmp_file;
    if(not $not_copied){
        # start mpdboot with new machinefile on master client
        my $bootres = $master->getRemoteConnector()->run(
            "sudo -u mpiuser ${mpdpath}mpdboot -n "
            ." ".scalar(@ips)
            ." -f ".$self->machinefile(),
            timeout=>300 );
        DEBUG "mpdboot out:".$bootres->{stdout};
        DEBUG "mpdboot err:".$bootres->{stderr};
       if(defined ($bootres->{exitcode})
                and ($bootres->{exitcode} == 0)){
            $master->ismpdready(1);
        }else{
            ERROR "mpdboot start failed";
        }
    }else{
        ERROR 'Cannot copy machinefile to '.$master->hostname();
    }
};

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
Copyright 2014 Seagate Technology

=head1 AUTHOR

Elena Gryaznova<Elena_Gryaznova@xyratex.com>
Roman Grigoryev<roman.grigoryev@seagate.com>

=cut


