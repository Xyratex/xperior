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

package checkyaml;
use strict;
use warnings;

use Test::Able;
use Test::More;

use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use Error qw(:try);
use Xperior::Xception;

startup         _startup  => sub {
    Log::Log4perl->easy_init($DEBUG);
};

setup           _setup    => sub { };
teardown        _teardown => sub { };
shutdown        _shutdown => sub { };

test plan => 3, cChekModule => sub{
    use Xperior::CheckConfig;
    my $res = checkDir("t/yamlcheckdata/1",0);
    is($res,1,'One check');

    try{
        checkDir("t/yamlcheckdata/1",1);
        fail ("No exception thrown");
    }catch NoSchemaException with{
        my $ex = shift;
        pass('Correct exception caught');
    }catch Error with {
        my $ex = shift;
        fail('Incorrect exception caught:'.$ex);
    }finally{
    };
    try{
        checkDir("t/yamlcheckdata/2",0);
        fail ("No exception thrown");
    }catch CannotPassSchemaException with{
        my $ex = shift;
        pass('Correct exception caught');
    }catch Error with {
        my $ex = shift;
        fail('Incorrect exception caught'.$ex);
    }finally{
    };

};

test plan => 3, eCheckProgram => sub {
    DEBUG `bin/checkyaml.pl  --dir='t/yamlcheckdata/1'`;
    my $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,0,"pass exit code");

    DEBUG `bin/checkyaml.pl  --dir='t/yamlcheckdata/1' --failonundef`;
    $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,2304,"no schema found, 0x0900");

    DEBUG `bin/checkyaml.pl  --dir='t/yamlcheckdata/2'`;
    $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,2048,"schema check doesn't pass, 0x0800");

};

checkyaml->run_tests;
