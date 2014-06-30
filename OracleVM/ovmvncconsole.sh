#!/bin/bash
# $Id: ovmvncconsole.sh 850 2013-08-22 07:32:49Z tbr $
#
# Copyright 2013 (c) Thorsten Bruhns (tbruhns@gmx.de)
#
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

# Parameter:
#           1 VM-ID from OVM-Manager or xm list
#           2 Hostname of OVM-Server
#           3 Local Port for VNCViewer
#
# Requirements:
#    This script needs a vncviewer and an exported DISPLAY
#    SSH-Connection to OVM-Server must be configured with public-key
#
#

if [ ${#} -ne 3 ]
then
	echo $(basename $0)" <VM-Id> <OVM-Servername> <lokaler VNC-Port>"
	echo "VNC-Display must be 2 diggits! 1 => 01"
	exit 1
fi

VMID=${1}
OVMSERVER=${2}
VNCDISPLAY=${3}
LOCALVNCPORT=59${VNCDISPLAY}

exittrap(){
	# kill a running ssh in background to close the tunnel	
	kill $SSHPID 2>/dev/null
}

check_running_vm(){
	echo "Check for running VM"
	ssh root@${OVMSERVER} xm uptime ${VMID}
	if [ ${?} -ne 0 ]
	then
		exit
	fi
}

start_tunnel(){
	# create ssh tunnel to ovm-server
	vncserverport=${1}
	sshtunnel=${LOCALVNCPORT}:localhost:${vncserverport}

	echo "opening SSH-Tunnel "${sshtunnel}
	ssh -t -t -L ${sshtunnel} root@${OVMSERVER} 1>/dev/null  &
	SSHPID=${!}
	export SSHPID

	# wait 3 secondes for creating the tunnel
	# => otherwise the start of vncview could fail due to missing tunnel
	echo "Waiting 3 seconds for establishing the ssh-tunnel in background"
	sleep 3 

	# check for running ssh-process
	ps -ef| awk '{print $2}' | grep "^"${SSHPID}"$"
	if [ ${?} -ne 0 ]
	then
		echo "ssh-tunnel not running!"
		exit 1
	fi
	
}

check_local_port(){
	echo
	echo "Check for free port on localhost!"
	nc -v -w 1 localhost ${LOCALVNCPORT}
	if [ ${?} -eq 0 ]
	then
		echo "Port "${LOCALVNCPORT}" is in use on localhost. Cannot open the ssh-tunnel!"
		exit 10
	else
		echo "Port is not in use. We can create a ssh-tunnel!"
	fi
}

get_vncport(){
	# get processid for Xen-Domain from ovm-server
	processid=$(ssh root@${OVMSERVER} ps -ef | grep "domain-name "${VMID} |grep -v grep| awk '{print $2}')

	# get the allocated vnc-Port for running domain from ovm-server
	suchstring=${processid}"/qemu-dm"
	vncserverport=$(ssh root@${OVMSERVER}  netstat -anp | grep "^tcp" | grep "${suchstring}" | cut -d":" -f2| awk '{print $1}')
	export vncserverport
}

trap exittrap EXIT INT TERM

check_local_port
check_running_vm
get_vncport
start_tunnel ${vncserverport}
vncviewer :${VNCDISPLAY}
 
