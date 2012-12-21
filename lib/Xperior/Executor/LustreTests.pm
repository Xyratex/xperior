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

extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = "0.0.2";

has 'mdsopt'  => ( is => 'rw' );
has 'ossopt'  => ( is => 'rw' );
has 'clntopt' => ( is => 'rw' );

after 'init' => sub {
    my $self = shift;
    $self->appname('sanity');

    #$self->reset;
    $self->reason('');
};

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

    $self->cmd( "SLOW=YES  "
          . $self->mdsopt . " "
          . $self->ossopt . " "
          . $self->clntopt
          . " $eopts $tid DIR=${dir}  PDSH=\\\"/usr/bin/pdsh -R ssh -S -w \\\" /usr/lib64/lustre/tests/${script}${ext}"
    );

}

=over 12

=item * B<processLogs> - parse B<test-framework.sh> test output and
calculate result based on output parsing.

Return values:

    0   - passed
    1   - skipped
    10  - failed
    100 - no result set based on parsing, failed toor

Also failure reason accessible (if defined) via call C<getReason>.

=back

=cut

sub processLogs {
    my ( $self, $file ) = @_;
    DEBUG("Processing log file [$file]");
    open( F, "  $file" );

    my $passed = 100;
    my $defreason = 'No_status_found';
    my $reason = $defreason;
    my @results;
    #consider only last keywords!
    while ( defined( my $s = <F> ) ) {
        chomp $s;
        if ( $s =~ m/PASS/ ) {
            $passed = 0;
            $reason = '';
        }
        if ( $s =~ m/FAIL:(.*)/ ) {
            $passed = 10;
            if( $reason eq $defreason){
                $reason = $1 if defined $1;
            }else{
                $reason = "$reason\n$1" if defined $1;
            }
        }
        if ( $s =~ /SKIP:(.*)/ ) {
            $passed = 1;
            $reason = $1 if defined $1;;
        }
        #don't see next messages after test end
        #================== 05:28:17
        if ( $s =~ /test\s+complete.*=+\s+\d\d:\d\d:\d\d\s+/){
            last;
        }
    }
    if ($passed) {
        $self->reason($reason);
    }
    close(F);
    return $passed;
}

sub _prepareEnvOpts {
    my $self    = shift;
    my $mdss    = $self->env->getMDSs;
    my $osss    = $self->env->getOSSs;
    my $clients = $self->env->getClients;
    $self->mdsopt('');
    my $c = 1;
    foreach my $m (@$mdss) {
        my $md = '';
        if((defined($m->{'device'}))
                and($m->{'device'} ne '')){
            $md =  "MDSDEV$c=".$m->{'device'};

        }
        $self->mdsopt( $self->mdsopt
              . " $md mds${c}_HOST="
              . $self->env->getNodeAddress( $m->{'node'} ).' '
              . " mds_HOST="
              . $self->env->getNodeAddress( $m->{'node'} ).' '
              );
        $c++;
    }
    $c--;
    $self->mdsopt( "MDSCOUNT=$c" . $self->mdsopt );

    $self->ossopt('');
    $c = 1;
    foreach my $m (@$osss) {
        my $sd = '';
        if((defined($m->{'device'}))
                and($m->{'device'} ne '')){
            $sd =  " OSTDEV$c=". $m->{'device'}

        }
        $self->ossopt( $self->ossopt
              . " $sd  ost${c}_HOST="
              . $self->env->getNodeAddress( $m->{'node'} )
              . ' ' );
        $c++;
    }
    $c--;
    $self->ossopt( "OSTCOUNT=$c" . $self->ossopt );

    #include only master client for sanity suite
    $self->clntopt('CLIENTS=');
    my $mclient;
    my @rclients;
    foreach my $cl (@$clients) {
        if ( ( defined( $cl->{'master'} ) && ( $cl->{'master'} eq 'yes' ) ) ) {
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

