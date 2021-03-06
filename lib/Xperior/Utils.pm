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
use POSIX ":sys_wait_h";
use Symbol 'gensym';
use Proc::Simple;
use Scalar::Util qw( isvstring looks_like_number);

our @ISA = ("Exporter");
our @EXPORT = qw(&shell &trim &runEx &parseFilterFile &findCompleteTests
    &is_path_unsafe &get_fs_root &is_any_pids_alive &kill_local_tree &xp_boolean);

=head2 xp_boolean

 This function return boolean value for logical parameters in xperior cli
 parameters or config files options

SYNOPSIS xp_boolean($var)

 The fucntion retrun 1 (perl logical true) if:
 * value is non zero integer
 * value is 'yes' or 'true' string with spaces before or afer words

=cut

sub xp_boolean{
    my $value = shift;
    if( defined($value) ){
        if ( looks_like_number($value)){
            return $value;
        }
        if( ( trim($value) eq 'yes' )
                or ( trim($value) eq 'true' ) ){
            return 1;
        }
    }
    return 0;
}


sub trim{
   my $string = shift;
   if(defined( $string)){
        $string =~ s/^\s+|\s+$//g;
   }
   return $string;
}

=head2 shell

Execute shell command with arguments, similar to system.

Warning! This call could locks internally in multithreading env.
Use it with cation!

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

=item timeout

Set timeout after which execution will be stopped
Default is 300 sec

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
    my $timeout  = $params{timeout} || 300;
    my $select_timeout  = 2;
    if (defined $prep) {
        $err_prep = "${err_prep}${prep}";
        $out_prep = "${out_prep}${prep}";
    }


    my @lines;
    DEBUG "Current work directory: [$CWD]";
    DEBUG "Executing command: [" . join (' ', @$cmd) . "]";
    my $start_time = time;
    my ($in,$out,$err);
    $err = gensym;
    my $pid = open3($in, $out, $err, join(" ", @$cmd));
    my $io = new IO::Select;
    $io->add($out,$err);

    #workaround
    #see http://stackoverflow.com/questions/24732682/waitpid-and-open3-in-perl
    my $exit_code_raw;
    my $is_exited = 0;
    while((time - $start_time)< $timeout){
      my @h = $io->can_read($select_timeout);
      if(scalar(@h)){
         for my $f (@h) {
            my $line = readline($f);
            unless (defined $line) {
               $io->remove($f);
               next;
            }

            if ($f eq $err) {
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
            if ($f eq $out) {
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
      }else{
         if(waitpid( $pid, WNOHANG ) > 0){
            $exit_code_raw=$?;
            $is_exited = 1;
            last;
         }

      }
      sleep 1;
    }

#    $exit_code_raw=$?;
#    my $kid = waitpid( $pid, WNOHANG);
    if ( not $is_exited ) {
       $exit_code_raw = $?;
       if( (waitpid( $pid, WNOHANG ) < 1)){
         $exit_code_raw = undef;
         WARN "Term child process [$pid]";
         kill 'TERM', $pid;
         if (waitpid( $pid, WNOHANG ) < 1) {
           WARN "Kill child process [$pid]";
           kill 'KILL', $pid;
         }
       }
    }

    my $elapsed_time = time - $start_time;
    DEBUG "Elapsed time: $elapsed_time (seconds)";
    #my $kill_signal = $exit_code_raw & 127;
    #my $core_dump   = $exit_code_raw & 128;
    my $exit_code   = (defined($exit_code_raw))?
                        $exit_code_raw >> 8 : 255;
    if ($?) {
        DEBUG "Exit code:   $exit_code";
        #DEBUG "Kill signal: $kill_signal";
    }
    return @lines if wantarray;
    return $exit_code;
}

=head2 runEx

Execute shell command with arguments, similar to system.
In practice, this solution is thereading safe and suggested for
usage as primary call for execution.

Parameters:

  * cmd          - command for execution
  * die_on_fail  - fail(confess) if executions failed
  * fail_message - optional message for 'confess' call


=cut
#TODO make this call useful-parametrized, add timeout
#TODO return result should be context-dependet, in hash context
#return same as in shell call
sub runEx{
    my ($cmd, $die_on_fail,$fail_message, $ptimeout ) = @_;
    my $timeout = 60*60*24; #set default timeout to 24h, magic!
    my $sleeptime = 1;
    DEBUG "Cmd is [$cmd]";
    DEBUG "WD  is [$CWD]";

    $die_on_fail  = 0 if ( !( defined $die_on_fail ) );
    $fail_message = '' if ( !( defined $fail_message ) );
    $timeout      = $ptimeout if ( $ptimeout );

    my $proc = Proc::Simple->new();
    $proc->kill_on_destroy(1);
    #$proc->redirect_output ("/tmp/someapp.stdout", "/tmp/someapp.stderr");
    my $st = time();
    $proc->start($cmd);
    while(
        (($st+$timeout) > time())
        and
        $proc->poll()){
        sleep $sleeptime;
    }
    if($proc->poll()){
        INFO "[$cmd] is working more then [$timeout] sec, killing";
        $proc->kill();
        sleep $sleeptime;
        ERROR "Sending SIGTERM";
        if ($proc->poll()){
            ERROR "Sending SIGKILL";
            $proc->kill("KILL");
        }
    }
    my $error_code = $proc->exit_status();
    if(not defined($error_code)){
        DEBUG "error_code is undefined";
        $error_code=254;#magic, haven't seen anybody who use it
    }
    my $time = time - $st;
    DEBUG "Execution time = $time sec";
    if ( ( $error_code != 0 ) and ( $die_on_fail == 1 ) ) {
        confess "Child process failed with error status $error_code."
                .$fail_message;
    }
    DEBUG "Return code is: [" . $error_code . "]";
    return $error_code;
}

# old stable code
sub runExOld{
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

=head2 is_path_unsafe

Check the list of roots (mount) and incoming parameter (path).

Return safe or not to avoid removing from root.

Returns exit codes as:

0 - patch is safe
1 - patch is unsafe
2 - patch is possible unsafe
3 - root list or path is empty

SYNOPSIS

    is_path_unsafe ( $fslist, $path )
    is_path_unsafe ( get_fs_root(), $path )

=cut
sub is_path_unsafe{
    my ($reflist, $path) = @_;

    #Checking if fslist reference exists
    if (!defined($reflist) || (ref($reflist) ne 'ARRAY') || !(@{$reflist})) {
        DEBUG "Subroutine parameter missing for filesystem list\n";
        #Return root list is empty
        return 3;
    }
    #Checking if path exists
    if (!$path) {
        DEBUG "Please cite the directory path which needs to be checked for safety\n";
        return 3;
    }
    if (grep{ $_ eq $path } @{$reflist}){
        #Return unsafe
        return 1;
    }
    return 0;
}

=head2 get_fs_root

Generates a list of filesystem roots using mount command on the local node.

Returns string array reference.


=cut

sub get_fs_root{
    my (@output, @all_words);
    @output = split(/\n/,`mount`);
    foreach my $line (@output){
        my @tmp_arr = split(' ', $line);
        push(@all_words,@tmp_arr);
    }
    return [grep(/^\//, @all_words)];
}

=head2 is_any_pids_alive(@pids)

Check process status for PIDs, return number of alives process
from list.

=cut

sub is_any_pids_alive{
    my @pids = @_;
    my $alive=0;
    foreach my $p (@pids) {
        my $ec = runEx("sudo kill -0 $p");
        if($ec !=0 ){
            #DEBUG "Process [$p] is not exists";
        }else{
            #DEBUG "Process [$p] alive";
            #DEBUG `ps afx | grep $p`;
            $alive++;
        }
    }
    return $alive;
}


=head2 kill_local_tree($pid, $kill_time)

Send TERM to $pid, sleep $kill_time sec, check processes alive,  and if alive
- send KILL

Assumption: proc group as same pid as pid in parameters (proc tree top)

*kill_tree* is local and not exported anymore

=cut
sub kill_tree{
    kill_local_tree(@_);
}

sub kill_local_tree{
    my ($pid, $kill_time) = shift;
    $kill_time = 1 unless $kill_time;
    my $gcmd = "pgrep -g ".$pid;
    my @pids = split(/\n/,`$gcmd`);
    DEBUG "Kill pids:".join(",",@pids);
    foreach my $p( @pids){
        DEBUG "run [sudo kill -TERM $p]";
        #Replace it to correct run with catching stdout/stderr
        DEBUG `sudo kill -TERM $p`;
    }
    #time to system kill and cleanup for highloaded systems
    sleep $kill_time;
    my $alive_pids = is_any_pids_alive(@pids);
    DEBUG "Proc status after TERM:". $alive_pids;
    if( $alive_pids ){
        foreach my $p( @pids){
            DEBUG "run [sudo kill -KILL $p]";
            DEBUG `sudo kill -KILL $p`;
        }
    DEBUG "Proc status:".is_any_pids_alive(@pids);
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

Roman Grigoryev<Roman_Grigoryev@xyratex.com>

=cut

