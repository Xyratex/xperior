use 5.010001;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest; 
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.ior.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.ior MANIFEST`."\n";
WriteMakefile(
    NAME              => 'XTests-ior',
    VERSION_FROM      => 'lib/XTests/Executor/IOR.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       =>  'IOR wrapper module for XTests harness', 
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : ()),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml XTests-ior*.tar.gz html "},
    
    
);
