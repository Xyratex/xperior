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
    $self->lustretestdir('/usr/lib64/lustre/tests');

    #$self->reset;
    $self->reason('');
};

after 'cleanup' => sub {
    my $self = shift;
    my $mclient = $self->_getMasterClient();
    my $mclientobj = $self->env->getNodeById( $mclient->{'node'} );
    my $testproc   = $mclientobj->getRemoteConnector();
    $testproc->createSync('rm -rf /tmp/test_logs')
};


=over 12

=item * B<_prepareCommands> - generate command line for Lustre test based on 
L<configuration|XperiorUserGuide/"System descriptor"> and test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    $self->_prepareEnvOpts;

    my $device_type = $self->env->cfg->{'lustre_device_type'} || 'loop';
    my $tempdir = $self->env->cfg->{'tempdir'} || '';
    my $dir     = $self->env->cfg->{'client_mount_point'} . $tempdir;
    my $eopts   = $self->env->cfg->{extoptions} || '';

    #TODO add test on it

    my $tid;
    # Workaround: tid should not be provided for 'lustre single' kind test
    # because ONLY is used to select, or we shouldn't provide an id
    # in test description for those scripts (that can harm logging)
    if( $self->test->getParam('groupname') ne 'lustre-single' ){
        $tid = $self->test->testcfg->{testname};
    }

    my $script = $self->test->getParam('script');
    unless ( $script ) {
        # build script name from 'groupname'
        my $groupname  = $self->test->getParam('groupname') ||
            confess "Group name is undefined";
        $script = "$groupname.sh";
    }

    my $lustre_script = "$self->{lustretestdir}/${script}";
    my @opt = (
                "SLOW=YES",
                "NAME=ncli",
                $self->mdsopt(),
                $self->ossopt(),
                $self->clntopt(),
                $eopts,
                "DIR=${dir}",
                "PDSH=\"/usr/bin/pdsh -R ssh -S -w \"",
    );
    # Test id can be 0, that is why checking for defined
    push @opt, "ONLY=$tid" if (defined $tid);

    if ($device_type eq 'block') {
        push @opt,
            "MDS_MOUNT_OPTS=\"-o rw,user_xattr\"",
            "OST_MOUNT_OPTS=\"-o user_xattr\"";
    }
    my $env = $self->test->getParam("env");
    if (ref($env) eq 'HASH') {
        for my $k (keys %$env) {
            push @opt,
                "$k=\"" . $env->{$k} . "\"";
        }
    }
    elsif ($device_type eq 'loop') {
        DEBUG "No additional options required for 'loop' devices";
    }
    $self->cmd( join( ' ', @opt, $lustre_script) );
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

=item * B<processLogs> - parse B<test-framework.sh> test output,
calculate result based on output parsing and find lines like this:
    Dumping lctl log to /tmp/test_logs/1365001494/replay-dual.test_9.*.1365001544.log
Dump file will be downloaded (if possible) and attach to test

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

    my $mclient    = $self->_getMasterClient;
    my $mclientobj = $self->env->getNodeById($mclient->{'node'});
    my $connector  = $mclientobj->getRemoteConnector();

    DEBUG("Processing log file [$file]");
    open( F, "  $file" );

    my $result    = $self->NOTSET;
    my $defreason = 'No_status_found';
    my $reason    = $defreason;
    my $is_completed = 0;
    my @results;

    while ( defined( my $s = <F> ) ) {
        chomp $s;
        $self->_parseLogFile($s,$connector);
        if ( not $is_completed ) {
            if ( $s =~ m/^PASS/ ) {
                $result = $self->PASSED;
                $reason = '';
                $is_completed = 1;
            }
            if ( $s =~ m/^FAIL(.*)/ ) {
                $result = $self->FAILED;
                $reason = $1 if defined $1;
                $is_completed = 1;
            }
            if ( $s =~ /^SKIP(.*)/ ) {
                $result = $self->SKIPPED;
                $reason = $1 if $1;
                $is_completed = 1;
            }
        }

    }
    if ($result) {
        $self->reason($reason);
    }
    close(F);
    return $result;
}

sub _parseLogFile{
    my $self      = shift;
    my $str       = shift;
    my $connector = shift;
    if ( my ($dumplog) = ( $str =~ m/Dumping lctl log to\s+(.*)$/ ) ) {
        DEBUG "Log files template [$dumplog] found in log";
        my $files = $connector->createSync("ls -Aw1 $dumplog");
        DEBUG "Found files : $files";
        if ( ( $connector->syncexitcode != 0 ) or ( $files eq '' ) ) {
            $self->addMessage("Cannot list lctl logs files[$dumplog]");
        }else {
            foreach my $file ( split( /\n/, $files ) ) {
                INFO "Attaching log file [$file]";
                my $sname = $file;
                $sname =~ s/^.*\///;
                $sname =~ s/\.log$//;
                $self->_getLog( $connector, $file, "lctllog.$sname" );
            }
        }
    }
}

sub _prepareEnvOpts {
    my $self    = shift;
    my @mdss    = $self->env->getMDSs;
    my @osss    = $self->env->getOSSs;
    my $clients = $self->env->getClients;
    my $c;
    my @opt = ();
    my $nettype='tcp';
    if($self->env->cfg->{'nettype'}){
        $nettype=$self->env->cfg->{'nettype'};
    }
    
    if($self->env->cfg->{'mgsnid'}){
        push @opt, 'MGSNID='.$self->env->cfg->{'mgsnid'};
    }else{
        DEBUG "No MSGNID defined, could be an reason for test failures";
    }

    if(defined($self->env->cfg->{'clientonly'}) 
        && $self->env->cfg->{'clientonly'} == 1){
        DEBUG "CLIENT ONLY mode selected";
        if(not $self->env->cfg->{'mgsnid'}){
            INFO "No MSGNID defined, could be an reason for test failures";
        }
        push @opt, "CLIENTONLY=1";
        $self->mdsopt( join( ' ', @opt ) );
        $self->ossopt(' ');
    }else{

        DEBUG "FULL FEATURED mode selected";
        $c = 1;
        push @opt, "NETTYPE=$nettype";
        foreach my $m (@mdss) {
            my $host = $self->env->getNodeAddress( $m->{'node'} );
            push @opt, "mds${c}_HOST=$host";
            push @opt, "MDSDEV$c=$m->{device}"
                if ( $m->{'device'} and ( $m->{'device'} ne '' ) );
            if ($c eq 1) { # lustre 1.8 legacy support
                push @opt, "mds_HOST=$host";
                push @opt, "MDSDEV=$m->{device}"
                    if ( $m->{'device'} and ( $m->{'device'} ne '' ) );
            }
            if ($m->{'failover'}) {
                my $failover = $self->env->getNodeAddress($m->{'failover'});
                if((not $self->env->cfg->{'mgsnid'}) && ($c eq 1)){
                    DEBUG "Construct MGSNID";
                    push @opt, "MGSNID=$host\@$nettype:$failover\@$nettype"
                }
                push @opt, "mds${c}failover_HOST=$failover";
                # lustre 1.8 legacy
                push @opt, "mdsfailover_HOST=$failover" if ($c eq 1);
            }
            $c++;
        }
        push @opt, "MDSCOUNT=" . scalar @mdss;
        $self->mdsopt( join( ' ', @opt ) );

        @opt = ();
        $c = 1;
        foreach my $m (@osss) {
            my $host = $self->env->getNodeAddress( $m->{'node'} );
            push @opt, "ost${c}_HOST=$host";
            push @opt, "OSTDEV$c=" . $m->{'device'}
              if ( $m->{'device'} and ( $m->{'device'} ne '' ) );
            if ($m->{'failover'}) {
                my $failover = $self->env->getNodeAddress($m->{'failover'});
                push @opt, "ost${c}failover_HOST=$failover";
            }
            $c++;
        }
        push @opt, "OSTCOUNT=" . scalar @osss;
        $self->ossopt( join( ' ', @opt ) );
    }

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
           "CLIENTS=$mclient RCLIENTS=\"" . join( ',', @rclients ) . "\"" );
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

