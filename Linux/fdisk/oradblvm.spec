Name:		oradblvm
Version:	0.1
Release:	1%{?dist}
Summary:	Scripts for creating physical Volumes, Volume Groups and Filesystem for Oracle Databases

Group:		Database/Tools
License:	GPL
URL:		https://github.com/Rendanic/oracleToolbox/tree/master/Linux
#Source0:	
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Vendor:         Thorsten Bruhns (thorsten.bruhns@googlemail.com)



%description


%prep
cd %{_topdir}/BUILD
#wget  -O create_oradb_lvm_fs.sh https://github.com/Rendanic/oracleToolbox/raw/master/Linux/fdisk/create_oradb_lvm_fs.sh
#wget  -O sfdisk_lvm_vg.sh https://github.com/Rendanic/oracleToolbox/raw/master/Linux/fdisk/sfdisk_lvm_vg.sh



%build


%install
mkdir -p $RPM_BUILD_ROOT/usr/local/bin
install -m 755 create_oradb_lvm_fs.sh  $RPM_BUILD_ROOT/usr/local/bin/
install -m 755 sfdisk_lvm_vg.sh  $RPM_BUILD_ROOT/usr/local/bin/


%clean
rm -rf $RPM_BUILD_ROOT
rm -rf %{_tmppath}/%{name}
rm -rf %{_topdir}/BUILD/%{name}


%files
%defattr(-,root,root,-)
/usr/local/bin/create_oradb_lvm_fs.sh
/usr/local/bin/sfdisk_lvm_vg.sh
%doc



%changelog
* Wed Jan 23 2014 Thorsten Bruhns <thorsten.bruhns@googlemail.com> [0.1]
  - 1st version

