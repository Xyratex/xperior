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
# Please  visit http://www.xyratex.com/contact if you need additional information or
# have any questions.
# 
# GPL HEADER END
# 
# Copyright 2012 Xyratex Technology Limited
# 
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

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


