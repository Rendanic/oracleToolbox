#!/bin/bash
#
# $Id: asmdg_online_all.sh 852 2013-08-23 06:21:19Z tbr $

set_env()
{
	ORATAB=/etc/oratab

	set environment from /etc/oratab
	# 1st line with +ASM will be used for CRS_HOME
	ORACLE_SID=`grep "^+ASM" ${ORATAB} |cut -d":" -f1`
	if [ ${?} -ne 0 ]
	then
		echo "ASM-Environment can't be found in oratab!"
		abort_script 82
	else
		export ORACLE_SID

		# getting ORACLE_HOME from oratab
		ORACLE_HOME=`cat ${ORATAB} | grep "^"${ORACLE_SID} | cut -d":" -f2`
		export ORACLE_HOME

		# if we have a grid infrastructure or oracle restart we get the ORACLE_BASE with
		# a executable from Oracle!
		ORACLE_BASE=`${ORACLE_HOME}/bin/orabase`
		export ORACLE_BASE

		PATH=${PATH}:${ORACLE_HOME}/bin
		export PATH
	fi
}

online_dg(){
	dg_name=$1
	echo
	echo "ASM-Disk state before online all"
	asmcmd lsdsk -k -G $dg_name
	asmcmd lsdsk -p -G $dg_name
	echo "Try to Online Diskgroup "$dg_name 
	asmcmd online -a -G  $dg_name -w
	echo "ASM-Disk state after online all"
	asmcmd lsdsk -k -G $dg_name
	asmcmd lsdsk -p -G $dg_name
}

online_all_dgs(){
	echo $(date +%c)" State of all DIskgroups"
	ps -elf | grep asm_pmon_+ASM|grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "ASM-Instance not running!"
		exit 1
	fi

	asmcmd lsdg
	for str in $(asmcmd lsdg --suppressheader| awk '{print $11 $13}' | grep -v  ^0 | sed 's/.$//')
	do
		do_change=1
		dg_name=$(echo  $str | cut -b2-)
		online_dg $dg_name
	done
	if [ ${do_change:-0} = 1 ]
	then
		echo
		echo $(date +%c)" State of all DIskgroups"
		asmcmd lsdg
	fi
}

set_env
online_all_dgs

