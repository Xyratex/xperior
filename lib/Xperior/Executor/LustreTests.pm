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

Xperior::Executor::LustreTests - Module which contains Lustre execution specific functionality

=head1 DESCRIPTION

Module which contains Lustre execution specific functionality

LustreTests execution module for Xperior harness. This module inherit
L<Xperior::Executor::SingleProcessBase> and provide functionality for
generating command line  for Lustre B<test-framework.sh> based tests
and parse these tests output.

Sample test descriptor there C<testds/sanity_tests.yaml>.

=cut

package Xperior::Executor::LustreTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;

extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = "0.0.2";

has 'mdsopt'        => ( is => 'rw' );
has 'ossopt'        => ( is => 'rw' );
has 'clntopt'       => ( is => 'rw' );
has 'lustretestdir' => ( is => 'rw' );

after 'init' => sub {
    my $self = shift;
    $self->appname('sanity');
    $self->lustretestdir('/usr/lib64/lustre/tests/');

    #$self->reset;
    $self->reason('');
};

before 'execute' => sub {
    my $self = shift;
    my $lres = '';
    my $mres = '';
    foreach my $node ( @{ $self->env->{'nodes'} } ) {
        my $c     = $node->getRemoteConnector;
        my $lfs   = $c->createSync('lfs df -i');
        my $mount = $c->createSync('mount | grep lustre');
        my $free  = $c->createSync('free');
        my $df    = $c->createSync('df');
        my $node  = $node->{'ip'};
        my $ldata = <<DATA
----------------- $node -----------------
<lfs df -i>
$lfs
<mount | grep lustre>
$mount

DATA
          ;
        my $mdata = <<DATA
----------------- $node -----------------
<free>
$free
<df>
$df

DATA
          ;

        $lres .= "$ldata\n";
        $mres .= "$mdata\n";
    }
    $self->_saveStatusLog( 'mount-info', $lres );
    $self->_saveStatusLog( 'memory-info',   $mres );
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

=over 12

=item * B<_prepareCommands> - generate command line for Lustre test based on L<configuration|XperiorUserGuide/"System descriptor"> and test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    $self->_prepareEnvOpts;
    my $td  = '';
    my $ext = '.sh';
    $td = $self->env->cfg->{'tempdir'} if defined $self->env->cfg->{'tempdir'};
    my $dir    = $self->env->cfg->{'client_mount_point'} . $td;
    my $tid    = 'ONLY=' . $self->test->testcfg->{id};
    my $script = $self->test->getParam('groupname');
    my $eopts  = '';

    #TODO add test on it
    $eopts = $self->env->cfg->{extoptions}
      if defined $self->env->cfg->{extoptions};
    if ( defined( $self->test->getParam('script') ) ) {
        $script = $self->test->getParam('script');
        $tid    = '';                                #no default test number
        $ext = '';    #ext must be set also when script is set
    }

    my @opt = (
                "SLOW=YES",
                "NAME=ncli",
                $self->mdsopt,
                $self->ossopt,
                $self->clntopt,
                $eopts,
                $tid,
                "DIR=${dir}",
                "PDSH=\\\"/usr/bin/pdsh -R ssh -S -w \\\"",
                $self->lustretestdir . $script . $ext
    );
    $self->cmd( join( ' ', @opt ) );
}

=over 12

=item * B<processSystemLog> - parse B<system log> test output and
find lines like this:
	LustreError: dumping log to /tmp/lustre-log.1360606441.2365

Dump file will be downloaded (if possible) and attach to test

=back

=cut

sub processSystemLog {
    my ( $self, $connector, $filename ) = @_;
    DEBUG("Processing log file [$filename]");
    my $isopen = open( F, "  $filename" );
    if ( !$isopen ) {
        INFO "Cannot open system log file [$filename]";
        return;
    }
    my $i = 0;
    while ( defined( my $s = <F> ) ) {
        chomp $s;
        if ( my ($dumplog) =
             ( $s =~ m/LustreError\:\s+dumping\s+log\s+to\s+(.*)$/ ) )
        {
            DEBUG "Log file [$dumplog] found in log";
            $self->_getLog( $connector, $dumplog, "dump.0" );
        }
    }
    close F;
}

=over 12

=item * B<processLogs> - parse B<test-framework.sh> test output and
calculate result based on output parsing.

Return values:

    Xperior::Executor::SingleProcessBase::PASSED
    Xperior::Executor::SingleProcessBase::SKIPPED
    Xperior::Executor::SingleProcessBase::FAILED
    Xperior::Executor::SingleProcessBase::NOTSET -no result set based 
                                                  on parsing, failed too

Also failure reason accessible (if defined) via call C<getReason>.

=back

=cut

sub processLogs {
    my ( $self, $file ) = @_;
    DEBUG("Processing log file [$file]");
    open( F, "  $file" );

    my $result    = $self->NOTSET;
    my $defreason = 'No_status_found';
    my $reason    = $defreason;
    my @results;

    while ( defined( my $s = <F> ) ) {
        chomp $s;
        if ( $s =~ m/^PASS/ ) {
            $result = $self->PASSED;
            $reason = '';
            last;
        }
        if ( $s =~ m/^FAIL(.*)/ ) {
            $result = $self->FAILED;
            $reason = $1 if defined $1;
            last;
        }
        if ( $s =~ /^SKIP(.*)/ ) {
            $result = $self->SKIPPED;
            $reason = $1 if $1;
            last;
        }

    }
    if ($result) {
        $self->reason($reason);
    }
    close(F);
    return $result;
}

sub _prepareEnvOpts {
    my $self    = shift;
    my $mdss    = $self->env->getMDSs;
    my $osss    = $self->env->getOSSs;
    my $clients = $self->env->getClients;
    my $c;

    my @mds_opt;
    $c = 1;
    foreach my $m (@$mdss) {
        my $host = $self->env->getNodeAddress( $m->{'node'} );
        push @mds_opt, "mds${c}_HOST=$host", "mds_HOST=$host";
        push @mds_opt, "MDSDEV$c=" . $m->{'device'}
          if ( $m->{'device'} and ( $m->{'device'} ne '' ) );
        $c++;
    }
    push @mds_opt, "MDSCOUNT=" . scalar @$mdss;
    $self->mdsopt( join( ' ', @mds_opt ) );

    my @oss_opt;
    $c = 1;
    foreach my $m (@$osss) {
        my $host = $self->env->getNodeAddress( $m->{'node'} );
        push @oss_opt, "ost${c}_HOST=$host";
        push @oss_opt, "OSTDEV$c=" . $m->{'device'}
          if ( $m->{'device'} and ( $m->{'device'} ne '' ) );
        $c++;
    }
    push @oss_opt, "OSTCOUNT=" . scalar @$osss;
    $self->ossopt( join( ' ', @oss_opt ) );

    #include only master client for sanity suite
    $self->clntopt('CLIENTS=');
    my $mclient;
    my @rclients;
    foreach my $cl (@$clients) {
        if ( $cl->{'master'} && $cl->{'master'} eq 'yes' ) {
            $mclient = $self->env->getNodeAddress( $cl->{'node'} );
        }
        else {
            push @rclients, $self->env->getNodeAddress( $cl->{'node'} );
        }
    }
    $self->clntopt(
           "CLIENTS=$mclient RCLIENTS=\\\"" . join( ',', @rclients ) . "\\\"" );
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

