use 5.010001;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest; 
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.openmpibench.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.openmpibench    MANIFEST`."\n";
WriteMakefile(
    NAME              => 'XTest-openmpibenchmarks',
    VERSION_FROM      => 'lib/XTest/Executor/OpenMPIBase.pm',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       =>  'IOR amd MDTest wrapper modules for XTest harness', 
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : ()),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml XTest-open*.tar.gz html "},
    
    
);
