%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: XTests harness core.
Name: xtests-harness
Version: %{version}
Release: %{release}
License: ???
Group: Development/Libraries
Source 
Requires: perl(Moose) >= 0.94
Requires: perl(Test-Able)
Requires: perl(Test-More)
Requires: perl(Log-Log4perl)
Requires: perl(File-chdir)

%description
TBD

%prep

%setup


%build
TD=%{_buildrootdir}/%{name}-%{version}-%{release}.%{_arch}/usr
export PATH=/usr/lib64/openmpi/bin/:$PATH
make mpiio

%install 
TD=$RPM_BUILD_ROOT/usr

install -d  ${TD}/bin/
install -d  ${TD}/share/doc/ior-%{version}


install -D -s -m 755  src/C/IOR      ${TD}/bin/
install -D -m 644     USER_GUIDE                ${TD}/share/doc/ior-%{version}
install -D -m 644     UNDOCUMENTED_OPTIONS      ${TD}/share/doc/ior-%{version}
install -D -m 644     COPYRIGHT                 ${TD}/share/doc/ior-%{version}
install -D -m 644     RELEASE_LOG               ${TD}/share/doc/ior-%{version}


%files
%{_bindir}/*
%doc %attr(0444,root,root)  /usr/share/doc/ior-%{version}/*



