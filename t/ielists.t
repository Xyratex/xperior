#
#===============================================================================
#
#         FILE:  ielists.t
#
#  DESCRIPTION:  
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  01/10/2012 10:20:50 PM
#===============================================================================
#!/usr/bin/perl -w
package ielists;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;

sub getTests{
    my $out = shift;
    my @res;
    foreach my $s (@$out){
        #print "# $s \n";
        if ( $s =~ m/Test\s+full\s+name\s+\:\s+\[(.+)\]/){
            #print "*********". $1."\n";
            push @res, $1;
        }
    }
    return \@res;
}



startup         _startup  => sub {};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################

test plan => 1, cFullList => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds`;
    my $tts = getTests(\@out);
    my @exp = (
          'replay-vbr/1a',
          'replay-vbr/1bx',
          'replay-vbr/1c',
          'replay-vbr/2a',
          'replay-vbr/2b',
          'replay-vbr/3a',
          'replay-vbr/3b',
          'replay-dual/6',
          'replay-dual/8',
          'replay-dual/9'
          );
    is_deeply($tts,\@exp,"Full list");
    #print Dumper $tts;

};


test plan => 2, eExcludeList => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --excludelist=t/testlists/exclude.list`;
    my $tts = getTests(\@out);
    my @exp = (
          'replay-vbr/1bx',
          'replay-vbr/1c',
          'replay-vbr/2a',
          'replay-vbr/2b',
          'replay-vbr/3a',
          'replay-vbr/3b',
          'replay-dual/8',
          'replay-dual/9'
          );
    is_deeply($tts,\@exp,"Single exclude list");

   @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --excludelist=t/testlists/exclude_r.list`;
    $tts = getTests(\@out);
    print Dumper $tts;
    @exp = (
          'replay-vbr/1a',
          'replay-vbr/1c',            
          'replay-vbr/2a',
          'replay-vbr/2b',
          'replay-vbr/3a',
          'replay-vbr/3b',
          );
    is_deeply($tts,\@exp,"Exclusion with r/e");


    
};

test plan => 2, eIncludeList => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.simple.list`;   
    my $tts = getTests(\@out); 
    
    print "Ready results:".Dumper $tts;
    my @exp = (
           'replay-vbr/1a',
           'replay-dual/9'
          );

    is_deeply($tts,\@exp,"Simple include list ");   
   

    my @out1 = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list`;
    my $tts1 = getTests(\@out1);

    my @exp1 = (
          'replay-dual/6',
          'replay-dual/8',
          'replay-dual/9'
          );
    is_deeply($tts1,\@exp1,"Simple include list with r/e");

};

test plan => 3, alIELists => sub {

    my @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.simple.list               --excludelist=t/testlists/exclude.list`;   
    my $tts = getTests(\@out); 
    
    #print "Ready results:".Dumper $tts;
    my @exp = (
           'replay-dual/9'
          );

    is_deeply($tts,\@exp,"Simple include list/exclude list ");   


    @out = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list               --excludelist=t/testlists/exclude.list`;   
    $tts = getTests(\@out); 
    
    #print "Ready results:".Dumper $tts;
    @exp = (
           'replay-dual/8',
           'replay-dual/9'
          );

    is_deeply($tts,\@exp,"Simple include list/exclude list ");   


    my @out1 = `bin/runtest.pl  --action=list --workdir=/tmp/lwd1  --config=systemcfg.yaml --testdir=t/testlists/testds --includelist=t/testlists/include.list     --excludelist=t/testlists/exclude_r.list`;  
    my $tts1 = getTests(\@out1);

    my @exp1 = ();
    is_deeply($tts1,\@exp1,"Empty result");
};

ielists->run_tests;
