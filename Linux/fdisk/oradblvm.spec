Name:		oradblvm
Version:	0.3
Release:	1%{?dist}
Summary:	Scripts for creating physical Volumes, Volume Groups and Filesystem for Oracle Databases

Group:		Database/Tools
License:	GPL
URL:		https://github.com/Rendanic/oracleToolbox/tree/master/Linux/fdisk
BuildArch:  noarch
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Vendor:         Thorsten Bruhns (thorsten.bruhns@googlemail.com)

%description
sfdisk_lvm_vg.sh
Creates a partition over whole disk, labeling it as phyiscal disk for LVM and creates a Volume-Group or add the disk to an existing Volume-Group

create_oradb_lvm_fs.sh
Creates logical Volumes with name oradatalv and fralv in given Volume-Group. Creating an ext3/4 filesystem an that Logical-Volumes and mkdir on /u02 and /u03 for the database.

%prep
cd %{_topdir}/BUILD
wget  -O create_oradb_lvm_fs.sh https://github.com/Rendanic/oracleToolbox/raw/master/Linux/fdisk/create_oradb_lvm_fs.sh
wget  -O sfdisk_lvm_vg.sh https://github.com/Rendanic/oracleToolbox/raw/master/Linux/fdisk/sfdisk_lvm_vg.sh

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
* Fri Jan 24 2014 Thorsten Bruhns <thorsten.bruhns@googlemail.com> [0.3]
  - Changed destination directory for scripts to /usr/sbin and changed architecture to noarch
* Thu Jan 23 2014 Thorsten Bruhns <thorsten.bruhns@googlemail.com> [0.2]
  - Bugs in both scripts fixed. False detection of filesystem on OL6/RHEL6
* Thu Jan 23 2014 Thorsten Bruhns <thorsten.bruhns@googlemail.com> [0.1]
  - 1st version
