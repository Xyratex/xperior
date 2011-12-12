use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
print `cp build/Makefile.harness.PL Makefile.PL` ."\n";
print `cp build/MANIFEST.harness MANIFEST`."\n";
WriteMakefile(
    NAME              => 'XTest-harness',
    VERSION_FROM      => 'lib/XTest/Core.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.10.0 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'XTest harness, system which allow execute many other tests via wrappering', 
       AUTHOR         => 'ryg <Roman_Grigoryev@xyratex.com>') : (),
       MAN1PODS => {
            'bin/runtest.pl'           => 'blib/man1/runtest.1',
            }     
      ),
    clean            =>     {FILES => "Makefile Makefile.old MANIFEST MYMETA.json MYMETA.yml XTest-harness*.tar.gz html "},

);
