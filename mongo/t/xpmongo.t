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
# Copyright 2015 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

package xpmongo;

use strict;
use warnings;
use Test::Able;
use Test::More;
use Carp;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use YAML::Syck;
use File::Slurp;
local $YAML::Syck::ImplicitTyping = 1;

Log::Log4perl->easy_init( { level => $DEBUG } );

startup startup => sub {
    Log::Log4perl->easy_init($DEBUG);
    use XpMongo;
};
setup setup => sub { };

teardown teardown => sub { };
shutdown shutdown => sub { };

test
  plan         => 4,
  cCheckUpload => sub {
        my $yaml_data = YAML::Syck::LoadFile('mongo/t/yamls/00userspace-tests.yaml');
        #DEBUG Dumper $yaml_data;
        #write_file('/tmp/xpmongo_test.orgyaml', Dumper($yaml_data));
        my $validated_yaml = XpMongo::_validate_doc_data($yaml_data);
        #DEBUG Dumper $validated_yaml;
        #write_file('/tmp/xpmongo_test.fixedyaml', Dumper($validated_yaml));
        is($validated_yaml->{log}->{netconsole_pnt_mero},
            '00userspace-tests.netconsole.mero.log',
            'Check replace');
        is($validated_yaml->{'testname'},
            '00userspace-tests',
            'Structure check #1');
         is($validated_yaml->{'sessionstarttime'},
             '1446794211',
             'Structure check #2');
         is($validated_yaml->{extoptions}->{'sessionstarttime'},
             '1446794211',
             'Structure check #3');
    };

xpmongo->run_tests;

