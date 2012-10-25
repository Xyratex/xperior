%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: Xperior dependencies meta package
Name: xperior-deps
Version: 1.0
Release:6%{?dist}
License: GPLv2
Vendor: Xyratex Technology Limited
Group: Development/Libraries
Requires: perl >= 1:5.8.0
Requires: perl-Autodia
Requires: perl-File-chdir
Requires: perl-Log-Log4perl
Requires: perl-Module-Load
Requires: perl-Moose >= 0.94
Requires: perl-MooseX-Clone
Requires: perl-Pod-ProjectDocs
Requires: perl-Proc-Simple
Requires: perl-TAP-Formatter-HTML
Requires: perl-Test-Able
Requires: perl-YAML-Tiny
BuildArch: noarch

%description
Meta package for resolving Xperior dependencies

%files

%pre

%post

