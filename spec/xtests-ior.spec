%define _unpackaged_files_terminate_build  0
%define _missing_doc_files_terminate_build 0
Summary: The IOR software is used for benchmarking parallel file systems using POSIX, MPIIO, or HDF5 interfaces.
Name: ior
Version: %{version}
Release: %{release}
License: GPL
Group: Utilities/System
Source http://localhost/storage/ior/src/ior-2.10.3.tar.gz
Requires:  openmpi  
%description
IOR can be used for testing performance of parallel file systems using various interfaces and access patterns.  IOR uses MPI for process synchronization.
IOR version 2 is a complete rewrite of the original IOR (Interleaved-Or-Random) version 1 code.

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



