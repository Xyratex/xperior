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
# Copyright 2014 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#
=pod

=head1 NAME

Xperior::Executor::LTPTests - Module which contains 
L<LTP|http://sourceforge.net/projects/ltp/> execution functionality

=head1 DESCRIPTION

The module contains LTP execution functionality

This module inherit L<Xperior::Executor::SingleProcessBase> and provide
functionality for generating command line  for LTP tests and parse
these tests output. LTP tests are executing on master client, minimal
lustre setup should define: only the one client node with C<'master: yes'>.

Sample test descriptor there F<testds/ltp-fs_tests.yaml>.

LTP test descriptors could be generrated via L<gentests> or manually, e.g.

    bin/gentests.pl --fw ltp --testds ..../testds --groupname ltp-fs-perms_simple
    --script ..../ltp-20140115/fs_perms_simple


LTP specific system descriptor option for point to LTP root dir
on master client:

    ltp_root_dir            : /opt/ltp
    
=cut

package Xperior::Executor::LTPTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;

extends 'Xperior::Executor::SingleProcessBase';

has 'reportdir' => ( is => 'rw', default => '/tmp/ltpfstests');
has 'cmdfile'   => ( is => 'rw', default => 'cmd');
has 'logfile'   => ( is => 'rw', default => 'log');
has 'outfile'   => ( is => 'rw', default => 'out');
=over 12

=item B<_prepareCommands> - generate command line for LTP test 
based on L<configuration|XperiorUserGuide/"System descriptor"> and
 test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    #$self->_prepareEnvOpts;

    my $ltpdir  = $self->env->cfg->{'ltp_root_dir'} 
                        || confess "LTP root dir is not set";
    my $tempdir = $self->env->cfg->{'tempdir'} || '';
    my $ldir    = $self->env->cfg->{'client_mount_point'} . $tempdir;
    #TODO define what should be done with ext env 
    #my $eopts   = $self->env->cfg->{extoptions} || '';

    my $ltpcmd = $self->test->getParam('cmd');
    if(($self->reportdir() eq '')or
       ($self->reportdir() eq '/') or
       ($self->reportdir() =~ /\/\s+/)){
        confess "Empty or root patch set as LTP report dir";
    }
    my $preparescript = 
        'rm -rf '.$self->reportdir().'/*'.
        ' ; mkdir -p '.$self->reportdir().
        " ; echo '${ltpcmd}'     > ".$self->reportdir()."/".$self->cmdfile();
    my $ltpscript = 
        "${ltpdir}/runltp -p ".
        " -f ".$self->reportdir()."/".$self->cmdfile().
        " -r ${ltpdir}".
        " -l ".$self->reportdir()."/".$self->logfile().
        " -o ".$self->reportdir()."/".$self->outfile().
        " -d ${ldir}".
        '  -b mds\@tcp:/lustre -B lustre';
    $self->cmd( "$preparescript ; $ltpscript" );
}

#sub processLogs {
#    my ( $self, $file ) = @_;
#    return $self->PASSED;
#}

=over 12

=item * B<processLogs> - parse B<LTP> test output,
calculate result based on output parsing and find lines like this:
    LOG File: /tmp/ltpfstests/log
    OUTPUT File: /tmp/ltpfstests/out
    FAILED COMMAND File: /test-tools/ltp/output/LTP_RUN_ON-out.failed

LOG file will be downloaded (if possible) and attach to test

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
            if ( $s =~ m/^INFO: ltp-pan reported all tests PASS/ ) {
                $result = $self->PASSED;
                $reason = '';
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
    if (( $str =~ m/LOG File\:\s+(.*)$/ ) or
        ( $str =~ m/OUTPUT File\:\s+(.*)$/ ) or
        ( $str =~ m/FAILED COMMAND File\:\s+(.*)$/ )) {
        my $ltplog = $1;
        DEBUG "Log file [$ltplog] found in log";
        if ( ( $connector->syncexitcode != 0 ) or ( $ltplog eq '' ) ) {
            $self->addMessage("Cannot attach logs file[$ltplog]");
        }else {
            INFO "Attaching log file [$ltplog]";
            my $sname = $ltplog;
            $sname =~ s/^.*\///;
            $sname =~ s/log$//;
            $sname = '.'.$sname if ($sname ne '');
            $self->_getLog( $connector, $ltplog, "ltp$sname" );
        }
    }
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



Copyright 2014 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut