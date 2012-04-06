%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: Xperior harness core.
Name: xperior-harness
Version: 0.0.2
Release:6%{?dist} 
License: TBD 
Group: Development/Libraries
Source: Xperior-harness-0.0.2.tar.gz 
Requires: perl-Moose >= 0.94
Requires: perl-MooseX-Clone
Requires: perl-Test-Able
Requires: perl-Log-Log4perl
Requires: perl-File-chdir
Requires: perl-Proc-Simple
Requires: perl-Autodia
Requires: perl-Pod-ProjectDocs
BuildRequires:  perl >= 1:5.8.0
BuildRequires:  perl(ExtUtils::MakeMaker)
BuildRequires:  perl(Moose) >= 0.94
BuildRequires:  perl-Test-Able
BuildRequires:  perl-YAML-Tiny
BuildArch: noarch

%description
TBD

%prep
%setup -q -n Xperior-harness-%{version}


%build
perl Makefile.PL 
make


%install 
TD=$RPM_BUILD_ROOT/opt/xyratex/xperior/
rm -rf $RPM_BUILD_ROOT
install -d ${TD}/bin
install -D  -m 755  bin/*.pl      ${TD}/bin/
install -d -m 755 ${TD}/lib/Xperior
install -d -m 755 ${TD}/lib/Xperior/Executor
install -D  -m 644 blib/lib/Xperior/*.pm ${TD}/lib/Xperior 
install -D  -m 644 blib/lib/Xperior/Executor/*.pm ${TD}/lib/Xperior/Executor 
install -d ${TD}/doc
install -D  -m 644  README     ${TD}/doc
install -D  -m 644  Changes    ${TD}/doc
install -D  -m 644  doc/*      ${TD}/doc
install -D  -m 644  systemcfg.yaml ${TD}
install -d ${TD}/testds
install -D  testds/*.yaml  ${TD}/testds/
find $TD -type f -name .packlist -exec rm -f {} \;
find $TD -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*

%check
#make test

%post
cd /opt/xyratex/xperior/
mkdir -p html
bin/gendocs.pl

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc %attr(0444,root,root) /opt/xyratex/xperior/doc/*
%attr(0444,root,root) /opt/xyratex/xperior/lib/*
%attr(0644,root,root) /opt/xyratex/xperior/testds/*
%attr(0644,root,root) /opt/xyratex/xperior/*.yaml
%attr(0755,root,root) /opt/xyratex/xperior/bin/*

%changelog
* Tue Mar 20 2012 ryg <Roman_Grigoryev@xyratex.com> 0.0.2
    Many updates in results processing. Stable ssh module. Improved improved include/exclude list processing. Added html report. Increased test coverage. 
* Mon Oct 24 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
    Added docs and docs generation after installation. 
* Mon Oct 24 2011 ryg <Roman_Grigoryev@xyratex.com> 0.0.1
    Initial package version.

