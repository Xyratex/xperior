#
#===============================================================================
#
#         FILE:  compatlustretests.t
#
#  DESCRIPTION:  Tests for Compat::LustreTests
#
#       AUTHOR:  ryg 
#      COMPANY:  Xyratex
#      CREATED:  05/07/2012 08:12:32 PM
#===============================================================================
package  compatlustretests;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;
use YAML qw "Bless LoadFile Load Dump";

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
    use Compat::LustreTests;
};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################

test plan => 9, cGetGeneratedTestSuite => sub {
    my $yaml = getGeneratedTestSuite(
            'replay-ost-single', 
            't/lustre/testds',
            't/lustre/tests');
    print  "\n----\n".Dumper $yaml ;
    is($yaml->{groupname},'replay-ost-single',"Check new value");
    is($yaml->{schema}, 'data/schemas/testds.yaml','Check merged value 1');
    is($yaml->{timeout}, 300, ,'Check merged value 2');
    #check
    is(scalar(@{$yaml->{'Tests'}}),9,'number of tests');
    is($yaml->{Tests}[0]->{id},'0a','first test id');
    is($yaml->{Tests}[0]->{dangerous},'yes','test dangerous');
    is($yaml->{Tests}[2]->{timeout},123,'test timeout');
    is($yaml->{Tests}[8]->{id},7,'last test id');
    isnt($yaml->{Tests}[8]->{timeout},999,'last test timeout');
};

test plan => 4, eWriteGeneratedTestSuiteFile => sub {
    my $nyamlfile = "/tmp/replay-ost-single_tests.yaml";
    print `rm -rf $nyamlfile`;
    writeGeneratedTestSuiteFile(
            '/tmp/', 
            'replay-ost-single', 
            't/lustre/testds',
            't/lustre/tests');
    if( -e $nyamlfile ){
        pass("Yaml file exists");
    }else{
        fail("No file generated");
    }
    my $yaml = LoadFile($nyamlfile);
    is($yaml->{groupname},'replay-ost-single',"Check new value");
    is($yaml->{timeout}, 300, ,'Check merged value 2');
    isnt($yaml->{Tests}[8]->{timeout},999,'last test timeout');

};

compatlustretests->run_tests;

