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
package ipminode;

use strict;
use warnings;
use Test::Able;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Error qw(try finally except otherwise);
use Xperior::Xception; 
use Xperior::Node;

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 
    use Xperior::Nodes::IPMINode; 
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################

test plan =>3, dCheckStartHalt => sub {
    my $obj = Xperior::Node->new(
            ipmi=>'10.76.50.53',
            ip  =>'10.76.50.51',
            id  => 'testipmi',
            user=>'root',
            nodetype=>'IPMINode'
            );
    $obj->start;
    my $r = $obj->isAlive;
    is($r,1,"Is vm active");
    my $ssh = $obj->waitUp(300);
    isnt($ssh, undef, "ssh defined");
    $obj->halt;
    $obj->sync;
    $r = $obj->isAlive;
    is($r,0,"Is vm stopped");    
};

#test plan =>2, aCheckRestore => sub {
#    DEBUG `rm -fv t/kvmnode.t.testdata/image`;
#    my $obj = Xperior::Nodes::KVMNode->new(
#            kvmdomain=>'mds',
#            host=>'mds',
#            kvmimage => 't/kvmnode.t.testdata/image',
#            restoretimeout => 1);
#    `echo 'changedimage' > t/kvmnode.t.testdata/image`;
#    try{
#        $obj->restoreSystem('t/kvmnode.t.testdata/source');
#        fail("No exception caught");
#    }catch Error with{
#        pass ("Exception passed");
#    }
#    finally{};
#
#    my $src =`cat 't/kvmnode.t.testdata/source'`;
#    chomp $src;
#    is($src,'originalsource',"check restored file");
#};

#########################################
ipminode->run_tests;


