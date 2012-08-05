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

test plan => 6, a_generateAndMergeTestSuiteExclude => sub {
    
    my $exarrempty = Compat::LustreTests::_generateTestSuiteExclude
            ('replay-ost-single','t/lustre/tests/replay-ost-single.sh');
    is(scalar(@{$exarrempty}), 0, "No excluded tests");

    
    my $exarr = Compat::LustreTests::_generateTestSuiteExclude
            ('sanity','t/lustre/tests/sanity.sh');
    is(scalar(@{$exarr}), 8, "8 excluded tests");
    is($exarr->[0],'sanity/27u',"Check name correctness");

    my $elist = Compat::LustreTests::_mergeWithPredefinedExclude
            ($exarr,'sanity','t/lustre/exclude.list');

    like($elist,qr/sanity\/68b/,'check new test there');
    like($elist,qr/lustre-single\/metadata-updates\s\#MRP-369/,
                'check old test there');
    #print $elist;
    my $elist1 = Compat::LustreTests::getGeneratedTestSuiteExclude('sanity','t/lustre/exclude.list',
                    't/lustre/tests/');
    is($elist,$elist1,'check that parts same as the whole');
};


test plan => 9, gGetGeneratedTestSuite => sub {
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

test plan => 4, hWriteGeneratedTestSuiteFile => sub {
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

