%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: The Lustre acc small wrapper for Xperior harnesss.
Name: xperior-lustretests
Version: 0.0.2 
Release: 4%{?dist} 
License: TBD 
Group: Development/Libraries
Source: Xperior-lustretests-0.0.2.tar.gz
Requires: lustre-tests 
Requires:  xperior-harness 
BuildArch: noarch

%description
TBD
%prep
%setup -q -n Xperior-lustretests-%{version}

%build
perl Makefile.PL 
make

%install 
TD=$RPM_BUILD_ROOT/opt/xyratex/xperior/
rm -rf $RPM_BUILD_ROOT
install -d ${TD}/lib/Xperior/Executor
install -D  -m 644 blib/lib/Xperior/Executor/*.pm ${TD}/lib/Xperior/Executor 
install -d ${TD}/lib/Xperior/Executor/Roles
install -D  -m 644 blib/lib/Xperior/Executor/Roles/*.pm ${TD}/lib/Xperior/Executor/Roles                                             
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
%attr(0444,root,root) /opt/xyratex/xperior/lib/*
%attr(0644,root,root) /opt/xyratex/xperior/testds/*


%changelog
* Wed Mar 21 2012 ryg <Roman_Grigoryev@xyratex.com> 0.0.3
    Wide improving, compatible with compatibility testing, many suites
* Mon Dec 13 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
    Initial package version.
