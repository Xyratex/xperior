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

Xperior::Utils - some utility functions


=head1 FUNCTIONS

=cut

package Xperior::Utils;
use strict;
use warnings;

use Carp;
use Log::Log4perl qw(:easy);
use Cwd qw(chdir);
use File::chdir;
use File::Path;
use File::Find;
use Data::Dumper;
use IO::Select;
use IPC::Open3;

our @ISA = ("Exporter");
our @EXPORT = qw(&shell &trim &runEx &parseFilterFile &findCompleteTests);

sub trim{
   my $string = shift;
   if(defined( $string)){
        $string =~ s/^\s+|\s+$//g;
   }
   return $string;
}

=head2 shell

Execute shell command with arguments, similar to system.

Returns exit code or stdout as array.

Allows to capture stdout and stderr as string or array.

Allows add prefix for dumping stdout and stderr.

SYNOPSIS

    shell ( "program arg1 arg2 ...", opt1 => val1, ... )
    shell ( ["program", "arg1", "arg2", ... ], opt1 => val1, ... )

OPTIONS

=over

=item out

Allow capture stdout, reference to string or array.

=item err

Allow capture stderr, reference to string or array.

=item out_prefix

Set stdout dumper prefix, string value.

=item err_prefix

Set stderr dumper prefix, string value.

=item prefix

Set prefix for both dumpers stderr and stdout.

=back

USAGE

=over

=item * Run command with options represented as array, and capture stdout in
C<$output> as string:

    $exit_code = shell (["command", $opts, ... ], out => \$output);

=item * Run command represented as string, return stdout as array of lines,
capture stderr in C<$errors> as string:

    @output = shell("command arg1 arg2 arg3", err => \$errors);

=item * Run command, capture stderr in array C<@err_lines>, checking exit code:

    if (shell("command args", err => \@err_lines)) {
        # process @err_lines
    }

=item * Run command and prepend each line of stdout and stderr dump
with C<server.org# > string. Save exit code in C<$exit_code> variable:

    $hostname  = "server.org";
    $exit_code = shell("command args", prefix => "${hostname}# ");

=item *

    $exit_code = shell("command", err => \@errors,
                                  out => \@output,
                                  err_prefix => "ERROR: ",
                                  out_prefix => "%%%%%% ");

=back

=cut
our $shell_err_prefix = "!!! ";
our $shell_out_prefix = "<<< ";
sub shell {
    my ($cmd, %params)  = @_;
    $cmd = [$cmd] unless ref($cmd);
    my $prep = $params{prefix};
    my $err_prep = $params{err_prefix} || $shell_err_prefix;
    my $out_prep = $params{out_prefix} || $shell_out_prefix;
    if (defined $prep) {
        $err_prep = "${err_prep}${prep}";
        $out_prep = "${out_prep}${prep}";
    }
    my @lines;
    DEBUG "Current work directory: [$CWD]";
    DEBUG "Executing command: [" . join (' ', @$cmd) . "]";
    my $start_time = time;
    my $pid = open3(\*IN, \*OUT, \*ERR, join(" ", @$cmd));
    my $io = new IO::Select;
    $io->add(\*OUT,\*ERR);
    while (my @h = $io->can_read) {
        for my $f (@h) {
            my $line = readline($f);
            unless (defined $line) {
                $io->remove($f);
                next;
            }

            if ($f eq \*ERR) {
                if (ref($params{err}) eq 'ARRAY') {
                    chomp($line);
                    push @{$params{err}}, $line;
                }
                elsif (defined $params{err}) {
                    ${$params{err}} .= $line;
                }
                chomp($line);
                WARN "${err_prep}${line}";
            }
            if ($f eq \*OUT) {
                if (ref($params{out}) eq 'ARRAY') {
                    chomp($line);
                    push @{$params{out}}, $line;
                }
                elsif (defined $params{out}) {
                    ${$params{out}} .= $line;
                }
                chomp($line);
                push @lines, $line if wantarray;
                DEBUG "${out_prep}${line}";
            }
        }
    }
    waitpid ($pid, 0);
    my $elapsed_time = time - $start_time;
    DEBUG "Elapsed time: $elapsed_time (seconds)";
    my $kill_signal = $? & 127;
    my $core_dump   = $? & 128;
    my $exit_code   = $? >> 8;
    if ($?) {
        DEBUG "Exit code:   $exit_code";
        DEBUG "Kill signal: $kill_signal";
    }
    return @lines if wantarray;
    return $exit_code;
}

# Depricated, please use 'shell' instead
sub runEx{
    my ($cmd, $dieOnFail,$failMess ) = @_;
    DEBUG "Cmd is [$cmd]";
    DEBUG "WD  is [$CWD]";

    $dieOnFail = 0 if ( !( defined $dieOnFail ) );

    my $st = time;
    my $error_code = system($cmd);
    my $time = time - $st;

    DEBUG "Execution time = $time sec";
    if ( ( $error_code != 0 ) and ( $dieOnFail == 1 ) ) {
        confess "Child process failed with error status $error_code";
    }

    DEBUG "Return code is: [" . $error_code . "]";
    return $error_code;
}

sub parseFilterFile{
    my $file = shift;
    DEBUG "Parse [$file] as include/exclude list";
    open(F,"< $file") or confess "Cannot open file: $file";
    my @onlyvalues;
    while(<F>){
        my $str=$_;
        chomp $str;
        my @nocomment = split (/#/,$str);
        next unless defined $nocomment[0];
        $nocomment[0] = trim( $nocomment[0]) if defined $nocomment[0];
        confess "Cannot parse file, space found on string [$str]:[".$nocomment[0]."]"
            if $nocomment[0] =~ m/\s+/ ;
        push(@onlyvalues, $nocomment[0]) if $nocomment[0] ne '';
    }
    close F;
    return \@onlyvalues;
}

sub findCompleteTests{
    my $workdir = shift;
    my @testlist;

    return \@testlist
        unless -d $workdir;

    find sub {
        my $file = $_;
        my $path =  $File::Find::name;
        $path =~ s/^$workdir//;
        $path =~ s/^\///;
        push (@testlist, $path) unless ( -d $file );
	}, $workdir;
    #DEBUG Dumper \@testlist;
    @testlist = sort @testlist;
    return \@testlist;
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

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

