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
            DEBUG "Call generateReport for [$file]";
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
        # show stdout via junit stdout
        if ( defined( $yaml->{'log'}->{'stdout'} ) ) {
            #TODO could take too much memory on real hw logs
            #replace to line by line reading from file
            my @lines = read_file( "$wd/$testclass/" . $yaml->{'log'}->{'stdout'},
                err_mode => 'carp');
            if(defined $lines[0]){
                foreach my $s (@lines) {
                        $s = $self->_doTextSafe($s);
                        $stdout = $stdout . $s;
                }
            }else{
                if ( defined($yaml->{'subtests'})) {
                    $stdout = "It is multitest, no single stdout"
                } else {
                    $stdout = "No stdout data found"
                }
            }
        }
        # show stderr via junit stderr
        if ( defined( $yaml->{'log'}->{'stderr'} ) ) {
            my @lines = read_file( "$wd/$testclass/" . $yaml->{'log'}->{'stderr'},
                err_mode => 'carp');
            if(defined $lines[0]){
                foreach my $s (@lines) {
                    $s = $self->_doTextSafe($s);
                    $stderr = $stderr . $s;
                }
            }else{
                if ( defined($yaml->{'subtests'})) {
                    $stdout = "It is multitest, no single stderr"
                }else{
                    $stdout = "No stdout data found"
                }
            }
        }

        $obj{'name'}      = 'test';
        $obj{'classname'} = $testclass . '.' . $yaml->{'id'};
        if(defined ($yaml->{'endtime'}) ){
            $obj{'time'} = $yaml->{'endtime'} - $yaml->{'starttime'};
        }else{
            $obj{'time'} = 0;
        }

        my $adir = $junitpath . "/" . $obj{'classname'};
        if (-e $adir and -d $adir) {
            DEBUG "[$adir] is exist and it is directory, ignore it";
        } elsif ( -e $adir ) {
            ERROR
            confess "[$adir] is not a directory! " ;
        }else{
            make_path($adir);
        }
        #this is hack
        #correct way is getting filenames from yaml file
        $stdout = $stdout."\n---jenkins metadata---\n";

        $stdout = $stdout . $self->_attach_logs($yaml, $wd, $testclass, $adir);
        foreach my $subtest (values %{$yaml->{'subtests'}})
        {
            $stdout = $stdout . $self->_attach_logs($subtest, $wd, $testclass, $adir);
        }
        foreach my $subtest (values %{$yaml->{'subtests_prepare'}})
        {
            $stdout = $stdout . $self->_attach_logs($subtest, $wd, $testclass, $adir);
        }

=item

        foreach my $lf ( values %{ $yaml->{'log'} } ) {
            #ignore coverage
            next if $lf =~ m/coverage/;
            runEx( "cp $wd/$testclass/$lf $adir", 0 );
            # see details in
            # http://kohsuke.org/?s=junit+attachment
            # https://wiki.jenkins-ci.org/display/
            # JENKINS/JUnit+Attachments+Plugin
            $stdout = $stdout. '[[ATTACHMENT|'.$adir.'/'.$lf."]]\n";
        }
=cut

        runEx( "cp $file    $adir", 1 );
        # see details
        #https://wiki.jenkins-ci.org/display/JENKINS/Measurement+Plots+Plugin
        #http://stackoverflow.com/questions/7559973/jenkins-with-the-
        #measurement-plots-plugin-does-not-plot-measurements
        $obj{'system-out'}{'content'} =
            $stdout.
            "<measurement><name>Time</name>".
            "<value>".$obj{'time'}."</value></measurement>";
        $obj{'system-err'}{'content'} = $stderr;


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

sub _attach_logs {
    my ( $self, $yaml, $wd, $testclass, $adir ) = @_;
    my $stdout = '';
    if( defined ( $yaml->{'log'} ) ){
        foreach my $lf ( values %{ $yaml->{'log'} } ) {
            #ignore coverage
            next if $lf =~ m/coverage/;
            runEx( "cp $wd/$testclass/$lf $adir", 0 );
            # see details in
            # http://kohsuke.org/?s=junit+attachment
            # https://wiki.jenkins-ci.org/display/
            # JENKINS/JUnit+Attachments+Plugin
            $stdout = $stdout.'[[ATTACHMENT|'.$adir.'/'.$lf."]]\n";
        }
    }
    return $stdout;
}

sub _doTextSafe {
    my ( $self, $s ) = @_;
    # replace low ascii symbols and DEL exclude \n
    $s =~ s/[\x00-\x09\x0B-\x1F\x7F]+/\?/g;
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
