use 5.010001;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest; 
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.lustre.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.lustre    MANIFEST`."\n";
WriteMakefile(
    NAME              => 'XTest-lustretests',
    VERSION_FROM      => 'lib/XTest/Executor/LustreTests.pm',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       =>  'Lustre executor runs and controls lustre  acc small test execution', 
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : ()),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml XTest-lustre*.tar.gz html "},
    
    
);
