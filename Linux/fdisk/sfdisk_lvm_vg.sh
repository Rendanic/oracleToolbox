#!/bin/bash
# $Id: sfdisk_lvm_vg.sh 633 2013-01-19 19:50:41Z tbr $
#
# (c) Thorsten Bruhns (tbruhns@gmx.de)

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

# ICH UEBERNEHME KEINE GARANTIE FUER DIE FUNKTION DES SKRIPTES
# FALSCHES ANWENDEN KANN ERHEBLICHEN DATENVERLUST NACH SICH ZIEHEN!

# Das Skript erzeugt auf einem Device eine 1. primaere Partition
# ueber den gesammten Bereich mit dem Typ LVM
# Disk Alignment wird dabei beruecksichtigt.
# sfdisk muss als Befehl verfuegbar sein!
#
# Im Anschluss wird eine Volume-Gruppe angelegt. Sollte die Gruppe
# bereits vorhanden sein wird sie entsprechend erweitert.
#
# ACHTUNG!!!
# Eine Disk ohne Partition wird dabei ueberschrieben. Disks mit
# bestehenden Partitionen werden nicht veraendert!
#
# Parameter 1: Device fuer sfdisk
# Parameter 2: Name der Volume-Gruppe

# todo: Ueberpruefung mittels blkid zur Sicherrung das kein Device genutzt wird!

set_env()
{
	# we need 2 parameter!
	if [ ${#} -ne 2 ]
	then
		echo " "
		echo `basename $0`" <physical Device> <Volume-Group>"
		echo " "
		echo "Example: "`basename $0`" /dev/xvds testvg"
		echo " "
		echo "This script creates a 1st primary partition on given disc for LVM when no partition table is existing"
		echo "The partition will labeled for LVM after then."
		echo "Finaly we create a Volume-Group with the new partition or extend an existing Volume-Group"
		exit 99
	fi
	sdpartition=${1}
	volumegroup=${2}
	
	pvpartition=${sdpartition}1

}
do_create_pv()
{
	# check for an existing partition
	# sfdisk prints the device only 1 times when no partition-table is existing
	countpart=`sfdisk -lR ${sdpartition} | grep ${sdpartition} | wc -l` 
	if [ ${countpart:-0} -eq 1 ]
	then
		# todo!!
		blkid ${sdpartition} > /dev/null
		retcode=${?}
		if [ ${retcode} -eq 0 ]
		then
			# found a valid filesystem or something else
			# => we can't create a parti	tion table here
			echo "blkid (blkid ${sdpartition}) found something on  "${sdpartition}
			echo "Aborting script!"
			exit 20
		fi
		
		pvdisplay ${sdpartition} > /dev/null 2>&1
		retcode=${?}
		if [ ${retcode} -eq 0 ]
		then
			# We found a valid physical volume on the disc!
			echo "Valid Label for LVM found on "${sdpartition}
			echo "Aborting script!"
			exit 30
		else
			# we have no physical volume on this disc!

			# => We can create a partition!
			echo "2048,,8e"|sfdisk -uS -q --force ${sdpartition} 
			if [ ${?} -eq 0 ]
			then
				blkid -g
				# sleep 2 seconds, because SLES11 SP2 doesn't find the partition for pvcreate
				sleep 2
	
				# we only create a physical volume when sfdisk was able to create the partition!
				# we can create the physical volume on the new partition
				echo "Creating a Label for LVM on "${pvpartition}
				pvcreate ${pvpartition}
			fi
		fi
	fi
}

do_make_vg()
{
	# is the device for LVM a block-device?
	if [ ! -b ${pvpartition} ]
	then
		echo "Cannot work on Volume-Group "${volumegroup}" because partition "${pvpartition}" is not a block device!"
		echo "Skript aborted!"
		exit 10
	fi

	# extend existing Volume Group or create a new one
	echo "Check for an existing Volume-Group"
	vgdisplay ${volumegroup} > /dev/null 2>&2
	retcode=${?}
	if [ ${retcode} -eq 0 ]
	then
		# Volume Group exists!
		vgextend ${volumegroup} ${pvpartition}
	else
		# creating a new Volume Group
		vgcreate ${volumegroup} ${pvpartition}
		# change max number of physical volumes for the new volume group
		echo "Change the maximum number of physical disks for the new Volume-Group"
		vgchange ${volumegroup} -p 0
	fi
}

set_env ${*}
do_create_pv
do_make_vg
 
