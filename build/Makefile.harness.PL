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
            'bin/runtest.pl'           => 'blib/man1/xperiror.1',
            'doc/XperiorDeveloperGuide.pod'        => 'blib/man1/XperiorDeveloperGuide.1',
            'doc/XperiorUserGuide.pod'             => 'blib/man1/XperiorUserGuide.1',
            'doc/XperiorInstallationGuide.pod'     => 'blib/man1/XperiorInstallationGuide.1',
            }     
      ),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml Xperior-harness*.tar.gz html "},

);
