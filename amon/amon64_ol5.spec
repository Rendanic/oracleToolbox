Name:		oracle-amon
Version:	0.38
Release:        1
Summary:	Free Performance Tool AMON from Andrej Simon
License:	GPL
URL:		https://sites.google.com/site/freetoolamon
BuildArch:      x86_64
BuildRoot:      %{_tmppath}/%{name}-build
Group:          Database/Tools
Vendor:         Thorsten Bruhns (thorsten.bruhns@googlemail.com), andrej.simon@oracle.com


%define _use_internal_dependency_generator 0
%define __find_requires %{nil}

%description
Free Performance Tool AMON from Andrej Simon
This rpm is build by Thorsten Bruhns for easy installation of the tool.

Binaries from: https://sites.google.com/site/freetoolamon


%prep
cd %{_topdir}/BUILD
wget  -nc https://github.com/Rendanic/oracleToolbox/raw/master/amon/bin/amon64_ol5

%build

%install
mkdir -p $RPM_BUILD_ROOT/usr/bin
install -m 755  amon64_ol5 $RPM_BUILD_ROOT/usr/bin

%clean
rm -rf $RPM_BUILD_ROOT
rm -rf %{_tmppath}/%{name}
rm -rf %{_topdir}/BUILD/%{name}

%files
%defattr(-,root,root)
/usr/bin/amon64_ol5
%doc

%changelog
* Sun Dec 15 2013 Thorsten Bruhns <thorsten.bruhns@googlemail.com> [0.38]
  - 1st version

