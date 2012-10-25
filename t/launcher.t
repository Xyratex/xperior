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

package launcher;
use strict;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::Able;
use Test::More;
use Data::Dumper;


startup         _startup  => sub {
 Log::Log4perl->easy_init({level => $DEBUG});
};
setup           _setup    => sub {};
teardown        _teardown => sub {};
shutdown        _shutdown => sub {};
#########################################

test plan => 2, cExitCodes => sub {

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/pass'`;
    my $res = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($res,0,"pass exit code");

    DEBUG `bin/runtest.pl  --action=run --workdir=/tmp/lwd1  --config=t/exitcodes/cfg.yaml  --testdir=t/exitcodes/ --debug --includeonly='lustre-single/exita.*'`;
    my $resa = ${^CHILD_ERROR_NATIVE};
    DEBUG "CHILD ERROR =[${^CHILD_ERROR_NATIVE}]";
    is($resa,0xc00,"exitafter exit code");


};

launcher->run_tests;
