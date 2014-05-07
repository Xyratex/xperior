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

Xperior::Reports::JenkinsJunit - provides functionality for generating
 Junit flavor which used by Jenkins for Xperior wokrdir

=cut

package Xperior::Reports::JenkinsJunit;
use strict;
use warnings;

use Moose;
use Log::Log4perl qw(:easy);
use XML::Simple;
use Data::Dumper;
use YAML qw "Bless LoadFile Load";
use File::Slurp;
use File::Basename;
use Xperior::Utils;
use File::Path qw(make_path remove_tree);

sub generateReport {
    my ( $self, $options ) = @_;
    my $wd = $options->{workdir};
    my $junitpath = $options->{jjunit};
    remove_tree($junitpath);
    make_path($junitpath);
    DEBUG "WD=$wd";
    my $dh;
    my @files =  grep { !/^\.+$/ } read_dir($wd);
    foreach my $file (@files) {
        DEBUG "Process suite [$file]";
        if(-d "$wd/$file" ){
            DEBUG "Call generateReport [$file]";
            $self->generateJunit( $options, $file );
        }
    }

}

sub generateJunit {
    my ( $self, $options, $testclass ) = @_;
    my $wd        = $options->{workdir};
    my $junitpath = $options->{jjunit};
    my $failures = 0;
    my $skipped  = 0;
    my $errors   = 0;
    my $tests    = 0;
    my $time     = 0;
    DEBUG "Suite dir=[$wd/$testclass]";
    my @files;
    @files = grep { /\.yaml$/ } read_dir("$wd/$testclass");
    my @testcases;

    foreach my $file (@files) {
        $file = "$wd/$testclass/$file";
        next if(($file eq 'testexecution.log')
                or ($file eq 'testorderplan.lst'));
        DEBUG "Check test result [$file]";
        my $yaml = LoadFile( $file ) or confess $!;
        my %obj;
        my $stdout = '';
        my $stderr = '';
        if ( defined( $yaml->{'log'}->{'stdout'} ) ) {
            my @lines = read_file( "$wd/$testclass/" . $yaml->{'log'}->{'stdout'} );
            foreach my $s (@lines) {
                    $s = $self->_doTextSafe($s);
                    $stdout = $stdout . $s;
            }
        }

        if ( defined( $yaml->{'log'}->{'stderr'} ) ) {
            my @lines = read_file( "$wd/$testclass/" . $yaml->{'log'}->{'stderr'} );
            foreach my $s (@lines) {
                $s = $self->_doTextSafe($s);
                $stderr = $stderr . $s;
            }
        }

        $obj{'system-out'}{'content'} = $stdout;
        $obj{'system-err'}{'content'} = $stderr;
        $obj{'name'}      = 'test';
        $obj{'classname'} = $testclass . '.' . $yaml->{'id'};
        if(defined ($yaml->{'endtime'}) ){
            $obj{'time'} = $yaml->{'endtime'} - $yaml->{'starttime'};
        }else{
            $obj{'time'} = 0;
        }

        my $adir = $junitpath . "/" . $obj{'classname'};
        make_path($adir);
        #this is hack
        #correct way is getting filenames from yaml file
        foreach my $lf ( values %{ $yaml->{'log'} } ) {
            #ignore coverage
            next if $lf =~ m/coverage/;
            runEx( "cp $wd/$testclass/$lf $adir", 0 );
        }
        runEx( "cp $file    $adir", 1 );

        #$yaml->{'executor'};
        if ( $yaml->{'status'} eq 'passed' ) {
            #$y
        }
        elsif ( $yaml->{'status'} eq 'skipped' ) {
            $obj{'skipped'}{'content'} = $yaml->{'fail_reason'};
            $skipped++;
        }
        else {
            $obj{'failure'}{'content'} =
              $yaml->{'fail_reason'} . "\n Messages :\n" . $yaml->{'messages'};
            $failures++;
        }
        $tests++;
        $time = $time + $obj{'time'};
        push @testcases, \%obj;
    }

    my %junit;
    $junit{testsuite}{testcase} = \@testcases;
    $junit{testsuite}{failures} = $failures;
    $junit{testsuite}{skipped}  = $skipped;
    $junit{testsuite}{errors}   = $errors;
    $junit{testsuite}{time}     = $time;
    $junit{testsuite}{tests}    = $tests;
    $junit{testsuite}{name}     = 'xperior';
    $junit{testsuite}{id}       = '1';

    my $xml = XML::Simple->new();
    my %ts;
    $ts{'testsuites'}            = \%junit;
    $ts{'testsuites'}{'name'}    = 'xtest';
    $ts{'testsuites'}{'package'} = 'xtest';
    #DEBUG $xml->XMLout( \%ts, KeepRoot => 1, AttrIndent => 1, NumericEscape => 2 );
    DEBUG "Write junit report for [$testclass]";
    write_file( "$junitpath/$testclass.junit",
        $xml->XMLout( \%ts, KeepRoot => 1, AttrIndent => 1,
             NumericEscape => 2 , keyattr => [])) ;
    return $xml;
}

sub _doTextSafe {
    my ( $self, $s ) = @_;
    $s =~ s/[\x00\x01\x02\x03\x04\x05\x06\x07\x08\x0c\x13\x14\x12]+/\?/g;    # low ascii symbols
    $s =~ s/0x/&#48; x/g;                                    #0x->
    return $s;
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

=head1 AUTHORS

Roman Grigoryev<Roman_Grigoryev@xyratex.com>,

=cut
