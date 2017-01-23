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
# Copyright 2013 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
# Co-Author: Ashish Maurya <ashish.maurya@seagate.com>

=pod

=head1 NAME

Xperior::Executor::Roles::StacktraceGenerator - Role define generatig
stacktrace into system console via /proc/ usage.

=head1 DESCRIPTION

Info about sysrt : https://www.kernel.org/doc/Documentation/sysrq.txt

The role could be used in cases when test failure detected and developer needs
more infomation about current system state. When role is switched on, it goes
over all nodes in system configuration and collect the stack trace and memory
trace via proc interface.
Stacktrace  and memorytrace will be stored in different files. The role is
recommended to use StacktraceGenerator with/or StoreConsole.


=cut

package Xperior::Executor::Roles::StacktraceGenerator;
use strict;
use warnings;
use Moose::Role;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Xperior::Utils;

my $title = 'StacktraceGenerator';
has executeutils  => (is => 'rw');
has sysrqtcmd     => (is => 'rw', default => 'echo t > /proc/sysrq-trigger');
has procmcmd      => (is => 'rw', default => 'cat /proc/sched_debug;
    cat /proc/zoneinfo; cat /proc/buddyinfo;
    cat /proc/meminfo');
has lctldkcmd        => (is => 'rw', default => 'sudo /usr/sbin/lctl dk');
has dmesgcmd         => (is => 'rw', default => 'dmesg');
has sysrqcmd_timeout => (is => 'rw', default => 60);
has proccmd_timeout  => (is => 'rw', default => 120);
has dumpend_timeout  => (is => 'rw', default => 60);
has proctcmd         => (is => 'rw', default => 'sudo cat /proc/');
has stack_part       => (is => 'ro', default => 'stack');

after 'execute' => sub {
    my $self = shift;
    my $filename;
    my $sysrq_trace;
    my $memory_trace;
    my $stack_trace;
    my $fh;
    my $stack_proccmd = $self->proctcmd();
    my $stack = $self->stack_part();

    if (($self->yaml->{status_code}) == 1) {
        foreach my $n (@{ $self->env->nodes }) {
            my $c = $n->getRemoteConnector();
            my $proc_op = $c->run("ls -a /proc/");
            if ($proc_op->{exitcode} != 0) {
                $self->addMessage(
                    "Error while listing '/proc/' entries on [".$n->id."]," .
                    " exitcode = $proc_op->{exitcode}");
                next;
            }
            my $all_proc = $proc_op->{stdout};
            if(!$all_proc) {
                DEBUG "Something Wrong: 'ls -a /proc/' output should not be empty";
                $self->addMessage("'ls -a /proc/' output should not be empty" .
                    " on [".$n->id."]");
                next;
            }
            my @cmds = map {"set +x;
                printf \",\nStack Trace of '\$(cat /proc/$_/comm 2> /dev/null)'($_):\n\";
                $stack_proccmd".$_."/$stack 2> /dev/null"}
                grep {/(\d+)/} split (/[\n\s]/, $all_proc);
            DEBUG("Call 'proc' commands on node [" . $n->ip() . "]");
            my $res = $c->run(\@cmds, timeout=>$self->proccmd_timeout, need_tty=>1);
            # In this case proc cmd was timed out or something went wrong
            if ($res->{killed} != 0 || $res->{exitcode} != 0) {
                INFO("Calling 'sysrq' commands on node [" . $n->ip() . "]");

                $res = $c->run($self->sysrqtcmd, timeout=>$self->sysrqcmd_timeout);
                if ($res->{exitcode} != 0) {
                    $self->addMessage(
                        "Error while running sysrq on [".$n->id."]," .
                        " exitcode = $res->{exitcode}");
                    next;
                }

                # Collect 'sysrq' traces along with dmesg o/p
                my $remote_sysrqtrace_file = "/tmp/dmesg." . $n->id;
                $res = $c->run($self->dmesgcmd . "&> $remote_sysrqtrace_file");
                if ($res->{exitcode} != 0) {
                    $self->addMessage("Error while getting 'dmesg' from [".$n->id."]," .
                    " exitcode = $res->{exitcode}");
                } else {
                    $res = $self->_getLog($c, $remote_sysrqtrace_file, 'sysrqtrace.'.
                    $n->id());
                    if($res != 0) {
                        $self->addMessage("Error while copying file from [".$n->id."]," .
                        " exitcode = $res->{exitcode}");
                    }
                    $c->run("rm -f $remote_sysrqtrace_file");
                }
            } else {
                my $stdout = join(' ', @{$res->{stdout}});
                my @stdout = map {trim($_)} split($c->stderr_delimiter, $stdout);
                my $stack_trace = join(' ', @stdout);
                DEBUG("Open stack trace file [$filename]");
                my $fh = $self->createLogFile('stacktrace.'. $n->id());
                if($fh < 0) {
                    $self->addMessage(
                        "Couldn't create stacktrace logfile on [".$n->id."]. ec=$!");
                    next;
                }
                print $fh $stack_trace;
                close($fh);
            }

            # Collect Memory Traces
            $res = $c->run($self->procmcmd, timeout=>$self->dumpend_timeout);
            if( $res->{exitcode} != 0) {
                $self->addMessage("Error while getting memory details
                    from '/proc' on [".$n->id."], ec = $res->{exitcode}");
            }
            $memory_trace = $res->{stdout};
            DEBUG("Open memory trace file [$filename]");
            my $fh = $self->createLogFile('memorytrace.'. $n->id());
            if($fh < 0) {
                $self->addMessage(
                    "Couldn't create memorytrace logfile on [".$n->id."]. ec=$!");
                next;
            }
            print $fh $memory_trace;
            close($fh);
            # Collect 'lctl dk' logs
            DEBUG("Call 'lctl dk' on node [" . $n->ip() . "]");
            my $remotelogfile = "/tmp/lctl_dk.out." . time ();
            $res = $c->run($self->lctldkcmd . " > $remotelogfile",
                timeout=>$self->dumpend_timeout, need_tty=>1);
            if ($res->{exitcode} != 0) {
               $self->addMessage("Error while getting 'lctl dk' from [".$n->id."]," .
               " exitcode = $res->{exitcode}");
            } else {
                $res = $self->_getLog($c, $remotelogfile, 'lctl_dk.' . $n->id());
                if($res != 0) {
                    $self->addMessage("Error while copying lctl_dk file from [".$n->id."]," .
                    " exitcode = $res->{exitcode}");
                }
            }
            $c->run("rm -f $remotelogfile");
        }

    }
    $self->afterAfterExecute($title);
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



Copyright 2013 Xyratex Technology Limited

=head1 AUTHOR

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut
