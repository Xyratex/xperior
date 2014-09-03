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

Xperior::Executor::LoadSimTests - Module contains
L<LoadSim|https://github.com/Xyratex/LoadSim>
execution specific functionality

=head1 DESCRIPTION

The module  contains LoadSim execution specific functionality for Xperior harness.
This module inherit L<Xperior::Executor::SingleProcessBase> and provide
functionality for generating command line for LoadSim tests, run 
them and parse tests output.

LoadSim tests are executed on master client, minimal lustre setup
should defined, e.g. only the one client node with C<'master: yes'>.

LoadSim specific system descriptor option to point to LoadSim build
directory on master client:

    mgsnid                  : 192.168.200.102@tcp

Sample test descriptor there C<testds/loadsim_tests.yaml>.

=cut

package Xperior::Executor::LoadSimTests;
use Moose;
use Data::Dumper;
use Carp qw( confess cluck );
use Log::Log4perl qw(:easy);
use File::Slurp;
use File::Temp;
use XML::Simple qw(:strict);

extends 'Xperior::Executor::SingleProcessBase';

our $VERSION = "0.0.1";


after 'init' => sub {
    my $self = shift;
    $self->reason('');
};

after 'cleanup' => sub {
    my $self = shift;
    my $mclient = $self->_getMasterClient();
    my $mclientobj = $self->env->getNodeById( $mclient->{'node'} );
    my $testproc   = $mclientobj->getRemoteConnector();
    $testproc->createSync(
            'rm -f /tmp/loadsim* && rm -f /tmp/remote_script*');
};


=over 12

=item * B<_prepareCommands> - generate command line for Lustre test based on
L<configuration|XperiorUserGuide/"System descriptor"> and test descriptor.

=back

=cut

sub _prepareCommands {
    my $self = shift;
    my $mgsnid = $self->env->cfg->{'mgsnid'} ||
        confess "No mgsnid set in system configuration";
    my $loadsimdir = $self->env->cfg->{'loadsimdir'} ||
        confess "No loadsimdir set in system configuration";

    my $id = $self->test->getParam('id') ||
        confess "Test id is undefined";

    my $script = $self->test->getParam('script') ||
        confess "Test script is undefined";

    my ($t $customscript) = 
        tempfile("localism_${id}_XXXXX", DIR=> '/tmp/')
    my @opt = (
                "cd $loadsimdir &&",
                "insmod  ./ksrc/sim.ko; ",
                'sed "s%[ \t][0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*@tcp%',
                "${mgsnid}\%g\" $script",
                "> ${customscript} ;",
                "src/mdsim -c $customscript",
    );

    $self->cmd( join( ' ', @opt) );
}


=over 12

=item * B<processLogs> - parse B<LoadSim> test output,
calculate result based on output and xml parsing

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

    my $result    = $self->NOTSET;
    my $reason    = 'No_status_found';
    my $out = XMLin($file,
            KeyAttr => { client => 'name' },
            ForceArray => [ 'client' ]
            );
    foreach my $clnt ( values %{$out->{'client'}}){
        DEBUG "wwwww=".$clnt->{'VM'}->{'status'};
        if($clnt->{'VM'}->{'status'} eq '0'){
            $result = $self->PASSED;
        }else{
            $result = $self->FAILED;
            $reason = $clnt->{'VM'}->{'status'};
        }
    }
    if ($result) {
        $self->reason($reason);
    }
    return $result;
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

