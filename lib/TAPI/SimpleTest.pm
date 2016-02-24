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
has 'reason'            => ( is => 'rw', default => '' );
has 'logname'           => ( is => 'ro', default => 'out' );
has 'logpath'           => ( is => 'rw');
has 'executor'          => ( is => 'rw');
has 'default_timeout'   => ( is => 'rw', default => 30);
has 'default_node'      => ( is => 'rw');

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
    my $time = "[".time."] $year/$mon/$mday $hour:$min:$sec";
    return $time;
}

sub fail{
    my ($self, %opts)     = @_;
    my $message  = $opts{message}  || '';
    my ($package, $filename, $line) = caller;
    my $source = "$package::$filename at $line";
     my $time = $self->htime();
    INFO "$message : FAILED";
    $self->failcount($self->failcount()+1);
    $self->append(
             $time."Directive fail at $source\n"
            ."==============================================\n"
            ."$message : FAILED\n");
    $self->reason("$message :FAILED")
                unless $self->reason();
    throw TestFailed ("$message : FAILED")
            unless defined $opts{dontfail};
}

sub contains{
    my ($self, %opts) = @_;
    my $message       = $opts{message}  || '';
    my $data          = $opts{value}
        || throw TestFailed("No value set for [$message]: FAILED");
    my $exp           = $opts{expected} || '';
    my $source        = $opts{source}   || '';
#    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
#                                                localtime(time);
#    $mon++;
#    my $time = "[".time."] $year/$mon/$mday $hour:$min:$sec";
    my $time = $self->htime();
    if( not $source ){
       my ($package, $filename, $line) = caller;
       $source = "$package::$filename at $line";
    }
    if( $data =~ m/$exp/m ){
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
    my $message  = $opts{message} ||  '';
    my $data     = $opts{value}
            || throw TestFailed("No value set for [$message]: FAILED");
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

sub run_check{
    my ( $self, %opts ) = @_;
    my $node     = $opts{node}     || $self->default_node();
    my $timeout  = $opts{timeout}  || $self->default_timeout();
    my $cmd      = $opts{cmd};
    my $message  = $opts{message}  || '';
    my $contains = $opts{contains} || '';
    my $negative = $opts{negative} || '';
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
    if( (not $negative and $run_res->{exitcode} == 0)
        or ($negative and $run_res->{exitcode} != 0)){
        INFO "Exit code [$run_res->{exitcode}], $message : PASSED";
        $self->append(
             $time." Check at $source\n"
            ."==============================================\n"
            ."Exit code is [$run_res->{exitcode}]\n"
            ."$message : PASSED\n");
        $self->contains( value    => $run_res->{stdout},
                         expected => $contains,
                         message  => $message,
                         source   => $source)
                                    if $contains;
        return $run_res;
    }else{
        INFO "Exit code is [$run_res->{exitcode}], $message :FAILED";
        $self->append(
            $time." Check at $source\n"
            ."==============================================\n"
            ."Exit code is [$run_res->{exitcode}]\n"
            ." $message :FAILED"
            ." cms is [$cmd]"
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

