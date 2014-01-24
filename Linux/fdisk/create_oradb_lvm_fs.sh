#!/bin/bash
# $Id: create_oradb_lvm_fs.sh 633 2013-01-19 19:50:41Z tbr $
#
# (c) Thorsten Bruhns (thorsten.bruhns@opitz-consulting.com)

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Das Skript erzeugt in der Volume-Gruppe 2 logical Volumes mit dem Namen
# fralv und oradatalv
# Es wird immer davon ausgegangen, das Oracle managed Files zum Einsatz kommen
# => Der Mountpoint fuer die Datenbank wird immer 'gross' geschrieben - unab-
#    haengig vom db_name!
#
# Die Filesysteme werden nach folgenden Schema eingehät: (db_name=TUX112)
# oradatalv => /u02/app/oracle/oradata/TUX112
# fralv     => /u03/app/oracle/fra/TUX112
#
# Parameter:
# 1. DB_NAME
# 2. Groesse in GB fuer oradata
# 3. Groesse in GB fuer fra
#
# Beispiel:
# create_oradb_lvs.sh TUX 80 10
#

set_env() {
	if [ ${#} -ne 3 ]
	then
		echo "Es muessen 3 Parameter uebergeben werden!"
		echo `basename $0`" <DB_NAME> <oradata groesse in GB> <fra groesse in GB>"
		echo "Beispiel: "`basename $0`" TUX11 30 10"
		exit 1
	fi

	oradbname=${1}
	vggruppe=oradb${oradbname}vg
	lvoradatasize=${2}
	lvfrasize=${3}

	# fstype ist bei SLES11 nur ext3, da ext4 nicht supported. :-(
	rpm -qa | egrep "^SLES-for-VMware-release|sles-release" > /dev/null 2>&1
	if [ ${?} -eq 0 ]
	then
		# SLES gefunden
		fstype=ext3
	else
		# alle anderen koennen ext4
		fstype=ext4
	fi
}

create_lv() {
	vggruppe=${1}
	lvname=${2}
	lvsize=${3}
	
	# LV vorhanden?
	lvdisplay /dev/${vggruppe}/${lvname} > /dev/null 2>&1
	if [ ! ${?} = 0 ]
	then
		# NEIN
		# => LV anlegen!
		echo "Erzeuge Logical Volume:"
		echo "lvcreate -n ${lvname} -L ${lvsize}g /dev/${vggruppe}" 
		lvcreate -n ${lvname} -L ${lvsize}g /dev/${vggruppe} >/dev/null
	else
		echo "Logical Volume "/dev/${vggruppe}/${lvname}" vorhanden!"
	fi
}

do_lvcreate() {
	create_lv ${vggruppe} oradatalv ${lvoradatasize}
	create_lv ${vggruppe} fralv ${lvfrasize}
}


create_extfs() {
	vggruppe=${1}
	lvname=${2}
	vollabel=${3}

	# nur wenn das lv tatsaechlich vorhanden ist wird versucht ein FS zu erzeugen
	lvdisplay /dev/${vggruppe}/${lvname} > /dev/null 2>&1
	if [  ${?} = 0 ]
	then
		# existiert bereits ein Filesystem?
		# funktioniert nur zuverlassig wenn das Filesystem bereits eingehaengt ist. :-(
		mkfs.${fstype} -n /dev/${vggruppe}/${lvname} > /dev/null 2>&1
		if [ ${?} = 0 ]
		then
			# probelauf erfolgreich
			# kein filesystem vorhanden, bestehendes filesystem ist nicht gemounted
			# => Filesystem darf erzeugt werden!
			echo "Erzeuge neues Filesystem auf "/dev/${vggruppe}/${lvname}
			mkfs.${fstype} -L ${vollabel} -m 1 -q /dev/${vggruppe}/${lvname}
		else
			echo "gueltiges Filesystem in "/dev/${vggruppe}/${lvname}" gefunden!"
		fi
	fi
}

do_mkfs() {
	# Volumelabel vom Filesystem darf nur max 16 Zeichen lang sein!
	create_extfs ${vggruppe} oradatalv "oradb"${oradbname}"dat"
	create_extfs ${vggruppe} fralv "oradb"${oradbname}"fra"
}

modify_fstab() {
	lvname=${1}
	mountpoint=${2}
		
	if [ ! -d ${mountpoint} ]
	then
		mkdir -p  ${mountpoint} 
	fi

	mountdevice="/dev/"${vggruppe}"/"${lvname}

	# pruefe ob ein Mountpoint in /etc/fstab schon vorhanden ist
	# existiert schon ein Eintrag in der fstag?
	grep "^"${mountdevice} /etc/fstab > /dev/null 2>&1
	if [ ! ${?} = 0 ]
	then
		# kein Eintrag vorhanden
		# => Eintrag einfuegen!
		echo "Erzeuge Eintrag fuer "${mountdevice}" in /etc/fstab"
		echo ${mountdevice}" 	"${mountpoint}" 	"${fstype}" 	defaults 0 0" >> /etc/fstab
	fi

	# Zur Sicherheit umount
	# => Der darf ruhig fehl schlagen - daher die Umleitung nach /dev/null
	umount ${mountdevice} > /dev/null 2>&1
		
	# Mount des neuen Filesystems
	mount ${mountdevice} > /dev/null 2>&1

	# Nur wenn der Mount erfolgreich ist, wird der chown durchgefuehrt!
	if [ ${?} = 0 ]
	then 
		# chown bewusst NUR auf das eingehaengte Verzeichnis und nicht auf das
		# Verzeichnis wo 'drauf' gemountet wird
		chown oracle ${mountpoint}
		echo " "
		echo "Verzeichnis erfolgreich eingehaengt:"
		df -h ${mountpoint}
	fi
}

do_fstab() {
	oradbnameupper=`echo ${oradbname} | tr '[:lower:]' '[:upper:]'`

	modify_fstab oradatalv 		/u02/app/oracle/oradata/${oradbnameupper}
	modify_fstab fralv 		/u03/app/oracle/fra/${oradbnameupper}
}

set_env ${*}
do_lvcreate 
do_mkfs
do_fstab

