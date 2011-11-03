%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: The MDTest and IOR wrapper for XTests harnesss.
Name: xtests-openmpibenchmarks
Version: 0.0.1 
Release: 4%{?dist} 
License: TBD 
Group: Development/Libraries
Source: XTests-openmpibenchmarks-0.0.1.tar.gz
Requires:  ior
Requires:  xtests-harness 
BuildArch: noarch

%description
TBD
%prep
%setup -q -n XTests-openmpibenchmarks-%{version}

%build
perl Makefile.PL 
make

%install 
TD=$RPM_BUILD_ROOT/opt/xyratex/xtests/
rm -rf $RPM_BUILD_ROOT
install -d ${TD}/lib/XTests/Executor
install -D  -m 644 blib/lib/XTests/Executor/*.pm ${TD}/lib/XTests/Executor 
install -d ${TD}/testds
install -D  testds/*.yaml  ${TD}/testds/

find $TD -type f -name .packlist -exec rm -f {} \;
find $TD -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*

%check
#set PERL5LIB /opt/xyratex/xtests/lib
perl  "-I/opt/xyratex/xtests/lib" "-MExtUtils::Command::MM" "-e" "test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
#make test

%post
cd /opt/xyratex/xtests/
mkdir -p html          %clean
bin/gendocs.pl         rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
#%doc %attr(0444,root,root) /opt/xyratex/xtests/doc/*
%attr(0444,root,root) /opt/xyratex/xtests/lib/*
%attr(0644,root,root) /opt/xyratex/xtests/testds/*

%changelog
* Mon Oct 25 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Initial package version.
* Mon Oct 25 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Doc generation added.
