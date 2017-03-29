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
# Author: Alexander Lezhoev<Alexander_Lezhoev@xyratex.com>
#

=pod

=head1 NAME

Xperior::Executor::Roles::StoreStat - Role define harvesting info from lustre nodes

=head1 DESCRIPTION
Role define harvesting info from lustre nodes

=cut

package Xperior::Executor::Roles::StoreStat;

use strict;
use warnings;
use Moose::Role;
use Time::HiRes;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use File::Slurp;
use threads;

my $title = 'StoreStat';
requires 'env';

sub collectStat {
    my ($self, $node) = @_;
    my $c     = $node->getRemoteConnector();
    my @cmds = (
                'lfs df -i',
                'lctl dl',
                'lfs df',
                'mount | grep lustre',
                'rpm -qi $(rpm -qa | grep lustre)',
                'free',
                'df'
            );

    my $res = $c->run(\@cmds);

    my ($lfs_i, $lctl_dl, $lfs, $mount, $lustre_rpm ,
        $client_rpm , $free, $df) = @{$res->{stdout}};
    my $node_ip  = $node->{'ip'};
    my $ldata = <<DATA
----------------- $node_ip -----------------
<lfs df -i>
$lfs_i
<lfs df>
$lfs
<lctl dl>
$lctl_dl
<mount | grep lustre>
$mount
<lustre>
$lustre_rpm
<lustre-client>
$client_rpm
DATA
    ;
    my $mdata = <<DATA
----------------- $node_ip -----------------
<free>
$free
<df>
$df

DATA
    ;
  return ( {lustre => $ldata, memory => $mdata} );
}

before 'execute' => sub {
    my $self = shift;
    $self->beforeBeforeExecute($title);
    my $lres = '';
    my $mres = '';

    my @threads = ();
    foreach my $node ( @{ $self->env->{'nodes'} } ) {
        my $count = 1;
        my $thr = threads->create(\&collectStat, $self, $node);
        while ( ($thr == undef) and ($count++ < 3) ){
            sleep 1;
            $thr = threads->create(\&collectStat, $self, $node);
        }

        if (defined $thr) {
            push @threads, $thr;
        }else{
            INFO "Cannot create StoreStat thread!!!";
        }
    }
    threads->yield;
    foreach (@threads){
        my $data = $_->join();
        $lres = $lres . $data->{lustre};
        $mres = $mres . $data->{memory};
    }
    $self->_saveStatusLog( 'mount-info',  $lres );
    $self->_saveStatusLog( 'memory-info', $mres );
    $self->afterBeforeExecute($title);
};

sub _saveStatusLog {
    my ( $self, $name, $res ) = @_;
    my $logfile = $self->getNormalizedLogName($name);
    if ( defined( write_file( $logfile, { err_mode => 'carp' }, $res ) ) ) {
        $self->registerLogFile( $logfile, $logfile );
    }
    else {
        $self->addMessage("Cannot create log file [$logfile ]: $res");
    }
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



Copyright 2012 Xyratex Technology Limited

=head1 AUTHOR

Alexander Lezhoev<Alexander_Lezhoev@xyratex.com>

=cut


