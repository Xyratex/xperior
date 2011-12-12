%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: The Lustre acc small wrapper for XTest harnesss.
Name: xtest-lustretests
Version: 0.0.1 
Release: 4%{?dist} 
License: TBD 
Group: Development/Libraries
Source: XTest-lustretests-0.0.1.tar.gz
Requires: lustre-tests 
Requires:  xtest-harness 
BuildArch: noarch

%description
TBD
%prep
%setup -q -n XTest-lustretests-%{version}

%build
perl Makefile.PL 
make

%install 
TD=$RPM_BUILD_ROOT/opt/xyratex/xtest/
rm -rf $RPM_BUILD_ROOT
install -d ${TD}/lib/XTest/Executor
install -D  -m 644 blib/lib/XTest/Executor/*.pm ${TD}/lib/XTest/Executor 
install -d ${TD}/testds
install -D  testds/*.yaml  ${TD}/testds/

find $TD -type f -name .packlist -exec rm -f {} \;
find $TD -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*

%check
#set PERL5LIB /opt/xyratex/xtest/lib
#perl  "-I/opt/xyratex/xtest/lib" "-MExtUtils::Command::MM" "-e" "test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
#make test

%post
cd /opt/xyratex/xtest/
mkdir -p html          %clean
bin/gendocs.pl         rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%attr(0444,root,root) /opt/xyratex/xtest/lib/*
%attr(0644,root,root) /opt/xyratex/xtest/testds/*

%changelog
* Mon Dec 13 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Initial package version.
