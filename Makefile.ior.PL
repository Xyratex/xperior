use 5.010001;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest; 
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
`cp Makefile.ior.PL Makefile.PL`;
`cp MANIFEST.ior MANIFEST`;
WriteMakefile(
    NAME              => 'XTests-ior',
    VERSION_FROM      => 'lib/XTests/Executor/IOR.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/XTests/Executor/IOR.pm', # retrieve abstract from module
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : ()),
);
