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
# Copyright 2015 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman.Grigoryev@seagate.com>
#

=pod

=head1 NAME

Xperior::Executor::MultiNodeSingleProcess - Definition
of multi test executor

=head1 DESCRIPTION

Class is inheritor of L<Xperior::Executor::Base> for
cumulative results for all process.

Class uses L<Xperior::SubTestResult> for keep test
result per process.

This executor is resposible for executing test which is
oriented to execution on multiple nodes, one process
per one node.

Usage examles in b<tests/Examples/Simple.pm>

=head1 FUNCTIONS


=cut

package TAPI::SimpleTest;

use Error  qw(try finally except otherwise);
use Moose;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp qw( confess cluck );
use File::Path;
use File::Copy;
use Proc::Simple;
use File::Slurp;
use Scalar::Util qw(looks_like_number);
use Xperior::Xception;


our $VERSION = '0.02';
has 'failcount'         => ( is => 'rw', default => 0 );
has 'errorcount'        => ( is => 'rw', default => 0 );
has 'reason'            => ( is => 'rw', default => '' );
has 'logname'           => ( is => 'ro', default => 'out' );
has 'logpath'           => ( is => 'rw' );
has 'executor'          => ( is => 'rw' );
has 'testds'            => ( is => 'rw' );
has 'default_timeout'   => ( is => 'rw', default => 30 );
has 'default_node'      => ( is => 'rw' );

sub append{
    my $self     = shift;
    my $data     = shift;
    if(not $self->logpath()){
        my $path =
            $self->executor->getNormalizedLogName($self->logname);
        $self->executor->registerLogFile($self->logname, $path);
        unlink($path);
        $self->logpath($path);
    }
    write_file( $self->logpath(), {append => 1}, $data ) ;
}

sub htime{
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
        = localtime(time);
    $mon++;
    $year = $year + 1900;
    my $time = "[".time."] $year/$mon/$mday $hour:$min:$sec";
    return $time;
}


=head3 log

=cut

sub log{
    my ($self, $message, %opts)  = @_;
    $self->append(
        $self->htime()." $message\n");
}

=head3 fail

Method for set status 'fail'. This status should be used
when test failed.

Parameters ( hash fields):

    * message   - message for logging
    * dontfail  - don't stop testing if defined and true

Examples

    $self->error(message=>"Don't panic");

=cut

sub fail{
    my ($self, %opts)     = @_;
    my $message  = $opts{message}  || '';
    my ($package, $filename, $line) = caller;
    my $source = "$package::$filename at $line";
     my $time = $self->htime();
    INFO "$message : FAILED";
    $self->failcount($self->failcount()+1);
    $self->append(
             $time." Directive fail at $source\n"
            ."==============================================\n"
            ."$message : FAILED\n");
    $self->reason("$message :FAILED")
                unless $self->reason();
    throw TestFailed ("$message : FAILED")
            unless defined $opts{dontfail};
}

=head3 error

Method for set status 'error'. This status should be used
when framework or code or configuration error detected.

Parameters ( hash fields):

    * message   - message for logging
    * dontfail  - don't stop testing if defined and true

Examples

    $self->error(message=>"Don't panic");

=cut

sub error{
    my ($self, %opts)  = @_;
    my $message       = $opts{message}  || '';
    my ($package, $filename, $line) = caller;
    my $source = "$package::$filename at $line";
    my $time = $self->htime();
    INFO "$message : ERROR";
    $self->errorcount($self->failcount()+1);
    $self->append(
        $time."Directive error at $source\n"
            ."==============================================\n"
            ."$message : ERROR\n");
    $self->reason("$message :ERROR")
        unless $self->reason();
    throw TestFailed ("$message : ERROR")
        unless defined $opts{dontfail} and $opts{dontfail};
}

=head3 contains

Method set current test status based on 'contains' check.
By default, perl regexp B<$data =~ m/$exp/m> for comparing.

Parameters ( hash fields):

    * value          - string for check, possible multiline
    * expected       - substring for search in value, pass if found
    * not_expected   - substring for search in value, fail  if found,
                       only expected or not_expected should be set.
    * message        - message for logging
    * check_sub      - set non-default check funtion there,
                        first parameter - value parameter,
                        second parameter - expected parameter
                        return value should be perl boolean
    * source         - use it for set caller info if needed, used internally
                       in xperior for unification
    * dontfail  - don't stop testing if defined and true.

if check failed and B<dontfail> is not set, testing stopped, status
'failed' set for tests.

Examples:

    #pass
    $self->contains(
        value     => 'qwerty asdfg',
        expected => 'qwerty',
        message  => "Don't panic");

    #custom check
    $self->contains(
        value      => 'qwerty asdfg ZZZZ',
        expected   => 'zzzz',
        check_sub  => sub {$_[0] =~ m/$_[1]/i},
        message    => "custom chech sub");

=cut

sub contains{
    my ($self, %opts) = @_;
    my $message       = $opts{message}  || '';
    my $data          = $opts{value}
        || throw TestFailed("No value set for [$message]: FAILED");
    my $exp           = $opts{expected} || '';
    my $not_exp       = $opts{not_expected}   || '';
    my $source        = $opts{source}   || '';
    my $check_sub     = $opts{check_sub}  || sub { $_[0] =~ m/$_[1]/m };
    if( not $exp and $not_exp){
        $check_sub  =  sub { $_[0] !~ m/$_[1]/m };
        $exp = $not_exp;
    }

    my $time = $self->htime();
    if( not $source ){
       my ($package, $filename, $line) = caller;
       $source = "$package::$filename at $line";
    }

    if ( $check_sub->($data, $exp) ) {
        INFO "[$data] contains [$exp], $message : PASSED";
        $self->append(
             $time." Contains check at $source\n"
            ."==============================================\n"
            .$data
            ."==============================================\n"
            ."contains [$exp]\n"
            ."$message : PASSED\n");
        return 1;
    }else{
        INFO "[$data] doesn't contain [$exp], $message :FAILED";
        $self->append(
            $time." Contains check at $source\n"
            ."==============================================\n"
            .$data
            ."==============================================\n"
            ."doesn't contain [$exp]\n"
            ." $message :FAILED");
        $self->failcount($self->failcount()+1);
        $self->reason("$message :FAILED")
            unless $self->reason();
        throw TestFailed("$message : FAILED")
            unless defined $opts{dontfail};
        return 0;
    }
}

sub is{
    my ($self, %opts)  = @_;
    my $message  = $opts{message}  ||  '';
    my $data     = $opts{value};
#            $self->error(message =>
#                    "No value set for [$message]: FAILED");
    my $exp      = $opts{expected} || '';
    my $time = $self->htime();
    my ($package, $filename, $line) = caller;
    my $source = "$package::$filename at $line";
    if((looks_like_number($data) and  $data == $exp)
        or $data eq $exp){
        INFO "[$data] = [$exp], $message : PASSED";
        $self->append(
             $time." Check at $source\n"
            ."==============================================\n"
            .$data." = [$exp]\n"
            ."$message : PASSED\n");
        return 1;
    }else{
        INFO "[$data] != [$exp], $message :FAILED";
        $self->append(
            $time." Check at $source\n"
            ."==============================================\n"
            .$data." != [$exp]\n"
            ." $message :FAILED");
        $self->failcount($self->failcount()+1);
        $self->reason("$message :FAILED")
            unless $self->reason();
        throw TestFailed("$message : FAILED")
            unless defined $opts{dontfail};
        return 0;
    }
}

=head3 run_check

Method set current test status based on 'contains' check.
By default, perl regexp B<$data =~ m/$exp/m> for comparing.

Parameters ( hash fields):

    * message        - message for logging
    * node           - node for run (B<SshProcess> object),
                       $self->default_node() by default
    * timeout        - command execution timeout,
                       $self->default_timeout() by default
    * cmd            - command for execution on B<node>, by default
                       cmd execution passed if exit code == 0 and
                       not timeouted
    * should_fail    - cmd execution passed if exit code > 0 and
                       not timeouted
    * exec_check_sub - custom check sub for exit code,
                        first parameter - killed parameter,
                        second parameter - expected parameter

    return value should be perl boolean

    set of options for additional contains check of stderr+stdout

    * contains      - substring for search in cmd (stdout+stderr),
                        pass if found
    * not_contains   - substring for search in cmd (stdout+stderr),
                       fail  if found, only expected or not_expected
                       should be set.

    * contains_check_sub  - set non-default contains check funtion

if check failed and B<dontfail> is not set, testing stopped, status
'failed' set for tests.

Examples:

    #pass
    $self->contains(
        value     => 'qwerty asdfg',
        expected => 'qwerty',
        message  => "Don't panic");

    #custom check
    $self->contains(
        value      => 'qwerty asdfg ZZZZ',
        expected   => 'zzzz',
        exec_check_sub  => sub {
                    return 0 if $_[0]; #false is killed
                    return 1 if $_[1] == 255; # true if exir code 255
                    return 0; # false in any other case
        },

        message    => "custom chech sub");

=cut

sub run_check{
    my ( $self, %opts ) = @_;
    my $node        = $opts{node}     || $self->default_node();
    DEBUG "Node is ". Dumper $node;
    my $timeout     = $opts{timeout}  || $self->default_timeout();
    my $cmd                = $opts{cmd};
    my $should_fail        = $opts{should_fail} || '';
    my $sub_exec_check     = $opts{exec_check_sub} || sub {
        return 0 if $_[0];
        return 0 if $_[1] != 0;
        return 1;
    };
    my $message            = $opts{message}  || '';
    my $contains           = $opts{contains} || '';
    my $not_contains       = $opts{not_contains} || '';
    my $contains_check_sub = $opts{contains_check_sub} || '';

    if( $should_fail ){
        $sub_exec_check     =  sub {
            return 0 if $_[0];
            return 0 if $_[1] == 0;
            return 1;
        };
    }

    if(not $node){
         throw TestFailed("node is not set!");
    }
    if( not $cmd){
         throw TestFailed("cmd is not set!");
    }
    DEBUG "timeout is [$timeout]";
    my $run_res  = $node->run($cmd, timeout=> $timeout);
    my $time = $self->htime();
    my ($package, $filename, $line) = caller;
    my $source = "$package::$filename at $line";
    if( $sub_exec_check->($run_res->{killled}, $run_res->{exitcode}) ){
        INFO "Exit code [$run_res->{exitcode}], $message : PASSED";
        $self->append(
             $time." Check at $source\n"
            ."==============================================\n"
            ."Exit code is [$run_res->{exitcode}]\n"
            ."Executed on [".$node->host()."]\n"
            ."Executed cmd [".$cmd."]\n"
            ."$message : PASSED\n");

        $self->contains( value    => $run_res->{stdout}.$run_res->{stderr},
                         expected => $contains,
                         not_expected => $not_contains,
                         check_sub => $contains_check_sub,
                         message  => $message,
                         source   => $source)
                                    if $contains or $not_contains;
        return $run_res;
    }else{
        INFO "Exit code is [$run_res->{exitcode}], $message :FAILED";
        $self->append(
            $time." Check at $source\n"
            ."==============================================\n"
            ."Exit code is [$run_res->{exitcode}]\n"
            ."Killed status is [".$run_res->{killled}."]\n"
            ."Executed on [".$node->host()."]\n"
            ." $message :FAILED"
            ." cmd is [$cmd]"
            ." stdout is \n"
            ."-------------cut------------\n"
            . $run_res->{stdout}
            ."\n-------------cut------------\n"
            ." stderr is \n"
            ."-------------cut------------\n"
            . $run_res->{stderr}
            ."\n-------------cut------------\n"
            );
        $self->failcount($self->failcount()+1);
        $self->reason("$message :FAILED")
            unless $self->reason();
        throw TestFailed("$message : FAILED")
            unless defined $opts{dontfail};
    }
    return $run_res;
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

Copyright 2015 Seagate

=head1 AUTHOR

Roman Grigoryev<Roman.Grigoryev@seagate.com>

=cut

