%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: XTests harness core.
Name: xtests-harness
Version: 0.0.1
Release:1%{?dist} 
License: ???
Group: Development/Libraries
Source: ./XTests-harness-0.0.1.tar.gz 
Requires: perl(Moose) >= 0.94
Requires: perl(Test-Able)
Requires: perl(Log-Log4perl)
Requires: perl(File-chdir)
BuildRequires:  perl >= 1:5.8.0
BuildRequires:  perl(ExtUtils::MakeMaker)
BuildRequires:  perl(Moose) >= 0.94
BuildRequires:  perl-Test-Able
BuildRequires:  perl-YAML-Tiny
BuildArch: noarch

%description
TBD

%prep
%setup -q -n XTests-harness-%{version}


%build
perl Makefile.PL 
make

%install 
TD=$RPM_BUILD_ROOT/opt/xtests/
rm -rf $RPM_BUILD_ROOT
#make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT/opt/xtests
install -d ${TD}/bin
install -D  -m 755  bin/runtest.pl      ${TD}/bin/
install -d ${TD}/lib/XTests
install -d ${TD}/lib/XTests/Executor
install -D  -m 644 blib/lib/XTests/*.pm ${TD}/lib/XTests 
install -D  -m 644 blib/lib/XTests/Executor/*.pm ${TD}/lib/XTests/Executor 
install -d ${TD}/doc
install -D  -m 644  README     ${TD}/doc/
install -D  -m 644  Changes    ${TD}/doc
install -D  -m 644  systemcfg.yaml ${TD}
find $TD -type f -name .packlist -exec rm -f {} \;
find $TD -depth -type d -exec rmdir {} 2>/dev/null \;

%{_fixperms} $RPM_BUILD_ROOT/*

%check
#TODO uncomment it!
#make test


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%attr(0755,root,root) /opt/xtests/bin/*
%doc %attr(0444,root,root) /opt/xtests/doc/*
%attr(0444,root,root) /opt/xtests/lib/*

%changelog
* Mon Oct 24 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
     Initial package version.

