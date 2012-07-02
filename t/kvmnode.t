#
#===============================================================================
#
#         FILE: kvmnode.t
#
#  DESCRIPTION: 
#
#       AUTHOR: ryg
# ORGANIZATION: Xyratex
#      CREATED: 06/29/2012 06:55:15 PM
#===============================================================================
#!/usr/bin/perl -w
package kvmnode;

use strict;
use warnings;
use Test::Able;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Error qw(:try);
use Xperior::Xception; 

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 
    use Xperior::Nodes::KVMNode; 
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################
test plan =>5, dCheckStartHalt => sub {
    my $obj = Xperior::Nodes::KVMNode->new(
            kvmdomain=>'mds',
            host=>'mds');
    is($obj->kvmdomain,'mds',"Check constructor 1");
    is($obj->restoretimeout,700,"Check constructor 2");
    $obj->start;
    my $r = $obj->isAlive;
    is($r,1,"Is vm active");
    my $ssh = $obj->waitUp(300);
    isnt($ssh, undef, "ssh defined");
    $obj->halt;
    $obj->sync;#not really need, just for testing
    $r = $obj->isAlive;
    is($r,0,"Is vm stopped");    
};

test plan =>2, aCheckRestore => sub {
    DEBUG `rm -fv t/kvmnode.t.testdata/image`;
    my $obj = Xperior::Nodes::KVMNode->new(
            kvmdomain=>'mds',
            host=>'mds',
            kvmimage => 't/kvmnode.t.testdata/image',
            restoretimeout => 1);
    `echo 'changedimage' > t/kvmnode.t.testdata/image`;
    try{
        $obj->restoreSystem('t/kvmnode.t.testdata/source');
        fail("No exception caught");
    }catch Error with{
        pass ("Exception passed");
    }
    finally{};

    my $src =`cat 't/kvmnode.t.testdata/source'`;
    chomp $src;
    is($src,'originalsource',"check restored file");
};
#########################################
kvmnode->run_tests;


