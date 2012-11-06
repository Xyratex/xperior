%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: The MDTest and IOR wrapper for Xperior harnesss.
Name: xperior-openmpibenchmarks
Version: 0.0.2
Release: 4%{?dist}
License: GPLv2
Vendor: Xyratex Technology Limited
Group: Development/Libraries
Source: Xperior-openmpibenchmarks-0.0.2.tar.gz
Requires:  ior
Requires:  xperior-harness
BuildArch: noarch

%description
TBD
%prep
%setup -q -n Xperior-openmpibenchmarks-%{version}

%build
perl Makefile.PL
make

%install
TD=$RPM_BUILD_ROOT/opt/xyratex/xperior/
rm -rf $RPM_BUILD_ROOT
install -d ${TD}/lib/Xperior/Executor
install -D  -m 644 blib/lib/Xperior/Executor/*.pm ${TD}/lib/Xperior/Executor
install -d ${TD}/testds
install -D  testds/*.yaml  ${TD}/testds/

find $TD -type f -name .packlist -exec rm -f {} \;
find $TD -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*

%check
#set PERL5LIB /opt/xyratex/xperior/lib
#perl  "-I/opt/xyratex/xperior/lib" "-MExtUtils::Command::MM" "-e" "test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
#make test

%post
cd /opt/xyratex/xperior/
mkdir -p html          %clean
bin/gendocs.pl         rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
#%doc %attr(0444,root,root) /opt/xyratex/xperior/doc/*
%attr(0444,root,root) /opt/xyratex/xperior/lib/*
%attr(0644,root,root) /opt/xyratex/xperior/testds/*

%changelog
* Mon Oct 25 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Initial package version.
* Mon Oct 25 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Doc generation added.
