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
use Error qw(try finally except otherwise);
use Xperior::Xception; 
use Xperior::Node;

startup         some_startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};
setup           some_setup    => sub { 
    use Xperior::Nodes::KVMNode; 
};
teardown        some_teardown => sub { };
shutdown        some_shutdown => sub {  };
#########################################

test plan =>4, cCheckConfg => sub {

    my $objn = Xperior::Node->new(
            kvmdomain =>'mds',            
            kvmimage =>'/tmp/noimage',
            ip =>'mds',                   
            user => 'root',               
            id => 'mdskvm',               
            nodetype => 'KVMNode'         
            ); 
    try{
        $objn->_findSerialFile;
        fail ("No exception for null console");
    }catch NullObjectException Error::subs::with {
        pass ("Exception cought");
    }

    $objn = Xperior::Node->new(
            console => 'notset',
            kvmdomain =>'mds',            
            kvmimage =>'/tmp/noimage',
            ip =>'mds',                   
            user => 'root',               
            id => 'mdskvm',               
            nodetype => 'KVMNode'         
            ); 
    try{
        $objn->_findSerialFile;
        fail ("No exception for null console");
    }catch NullObjectException Error::subs::with {
        pass ("Exception cought");
    }



    my $obj = Xperior::Node->new(
            kvmdomain =>'mds',            
            kvmimage =>'/tmp/noimage',
            console  =>'0',
            ip =>'mds',                   
            user => 'root',               
            id => 'mdskvm',               
            nodetype => 'KVMNode'         
            ); 
    
    my $xml = $obj->getConfg;
    like( $xml, qr/target port='0'/,'Check xml field');
    my $serial = $obj->_findSerialFile;
    ok(-e $serial, "Check file exists");
    #can be false if VM just created or just after reboot
};

test plan =>5, akCheckDumpStore => sub {
    my $obj = Xperior::Node->new(
            kvmdomain =>'mds',
            kvmimage =>'/tmp/nofile',
            console  =>'0',
            ip =>'mds',
            user => 'root',
            id => 'mdskvm',
            nodetype => 'KVMNode',            
            );
    my $kdump = '/tmp/testkerneldump';
    unlink $kdump;
    $obj->start;
    $obj->waitUp;
    my $ccdr = $obj->cleanCrashDir; 
    is($ccdr,0,"clean crashdump dir");

    my $res = $obj->storeKernelDump($kdump);
    is($res,-1,"getting crashdump");

    #generate crash dump
    try{
        $obj->run("echo \'c\' > /proc/sysrq-trigger",5);
        fail("system is not crashed");
    }catch CannotConnectException  Error::subs::with{
        pass("system crashed");
    };
    $res = $obj->storeKernelDump($kdump);
    is($res,-1,"getting crashdump for down host");  
    #start and wait anf find one dump

    #mean wait while kore dumped
    $obj->waitDown;

    $obj->start;
    $obj->waitUp;
    $res = $obj->storeKernelDump($kdump);
    is($res,0,"crashdump stored");  
};


test plan =>8, eCheckStartHaltConfig => sub {
    my $obj = Xperior::Node->new(
            kvmdomain =>'mds',
            kvmimage =>'/tmp/noimage',
            console  =>'0',
            ip =>'mds',
            user => 'root',
            id => 'mdskvm',
            nodetype => 'KVMNode' 
            );
    is($obj->kvmdomain,'mds',"Check constructor 1");
    is($obj->restoretimeout,700,"Check constructor 2");

    $obj->halt; #stop if previously was started

    my $cf = '/tmp/temp_consolestore_file';
    DEBUG `sudo rm $cf`;
    DEBUG `touch $cf`;
    $obj->start;
    my $r = $obj->isAlive;
    is($r,1,"Is vm active");
    
    $obj->startStoreConsole($cf);
    my $fs1 = -s $cf;
    DEBUG "Size after start is $fs1";
    ok(defined($fs1),"console file size is defined");
    ok(($fs1 < 200),"Just started colsole file");

    my $ssh = $obj->waitUp(300);
    isnt($ssh, undef, "ssh defined");
    $obj->halt;
    
    $obj->stopStoreConsole;
    my $fs2 = -s $cf;
    DEBUG "Size after stop is $fs2";
    ok(($fs2 >15000),"Colsole file after some work");

    $obj->sync;#not really need, just for testing
    $r = $obj->isAlive;
    is($r,0,"Is vm stopped");
};

test plan =>2, lCheckRestore => sub {
    DEBUG `rm -fv t/kvmnode.t.testdata/image`;
    my $obj = Xperior::Node->new(
            ip =>'mds',
            id => 'mdskvm',
            user => 'root',
            nodetype => 'KVMNode', 
            kvmdomain=>'mds',
            kvmimage => 't/kvmnode.t.testdata/image',
            restoretimeout => 1);
    `echo 'changedimage' > t/kvmnode.t.testdata/image`;
    try{
        $obj->restoreSystem('t/kvmnode.t.testdata/source');
        fail("No exception caught");
    }catch Error Error::subs::with{
        pass ("Exception passed");
    }
    finally{};

    my $src =`cat 't/kvmnode.t.testdata/source'`;
    chomp $src;
    is($src,'originalsource',"check restored file");
};
#########################################
kvmnode->run_tests;


