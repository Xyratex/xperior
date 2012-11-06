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
use ExtUtils::Manifest;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.openmpibench.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.openmpibench    MANIFEST`."\n";
WriteMakefile(
    NAME              => 'Xperior-openmpibenchmarks',
    VERSION_FROM      => 'lib/Xperior/Executor/OpenMPIBase.pm',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       =>  'IOR amd MDTest wrapper modules for Xperior harness',
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : ()),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml Xperior-open*.tar.gz html "},


);
