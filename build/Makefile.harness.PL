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
# Please  visit http://www.xyratex.com/contact if you need additional
# information or have any questions.
#
# GPL HEADER END
#
# Copyright 2012 Xyratex Technology Limited
#
# Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
#

use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.harness.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.harness MANIFEST`."\n";
WriteMakefile(
    NAME              => 'Xperior-harness',
    VERSION_FROM      => 'lib/Xperior/Core.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.10.0 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'Xperior harness, system which allow execute many other tests via wrappering',
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : (),
       MAN1PODS => {
            'bin/runtest.pl'           => 'blib/man1/xperior.1',
            'doc/XperiorDeveloperGuide.pod'        => 'blib/man1/XperiorDeveloperGuide.1',
            'doc/XperiorUserGuide.pod'             => 'blib/man1/XperiorUserGuide.1',
            'doc/XperiorInstallationGuide.pod'     => 'blib/man1/XperiorInstallationGuide.1',
            }
      ),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml Xperior-harness*.tar.gz html "},

);
