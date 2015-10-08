#!/bin/bash
#
# $Id: rman_backup.sh 873 2013-08-26 13:19:27Z tbr $
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# Simple RMAN-Backupscript 
#
# Parameter 1: ORACLE_SID
# Parameter 2: Backuptype (<Filename>.rman)
# Parameter 3: Directory for .rman-Files (not required!)
#
# This script search for an rman-file in $ORACLE_BASE/admin/$ORACLE_SID/rman
# with filename <parameter 2>.rman. This search could be changed with 3rd parameter.
# 
# The script checks for an existing directory $ORACLE_BASE/admin/$ORACLE_SID/rman/log.
# Backup will not start when directory or backupscript is not existing.
# Script will check for a catalog. When the catalog is not reachable the backup
# will run without a catalog.
# Configuration for RMAN-Catalog is done with Environment variable CATALOGCONNECT
# Example:
# CATALOGCONNECT=rman/catalog@hostname:port/service
# rman target / catalog $CATALOGCONNECT
#
# Major actions are logged in syslog of operating system
# A Logfile with name $ORACLE_BASE/admin/$ORACLE_SID/rman/log/<backuptyp>.log includes
# all output from RMAN
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
#
#

print_syslog()
{
	# Don't write to syslog when logger is not there
	which logger > /dev/null 2>&1
	retcode=${?}
	
	if [ ${retcode} -eq 0 ]
	then
		logger `basename $0` $param1 $param2 : " "${*}
	fi
}

abort_script()
{
	print_syslog "Abort Code="${1}
	exit ${1}
}

check_catalog() {
	# check for availible catalog
	# catalog not working => switch to nocatalog!
	print_syslog "Check for working RMAN Catalog"
	catalogconnect="connect catalog "${CATALOGCONNECT}
	${ORACLE_HOME}/bin/rman << _EOF_
connect target /
${catalogconnect} 
_EOF_

	retcode=${?}
	if [ ${retcode} -eq 0 ]
	then
		print_syslog "Using Catalog for Backup!"
	else
		# catalog not working
		# => clear variable
		catalogconnect=''
		export catalogconnect
		print_syslog "Catalog not reachable. Working without Catalog!"
	fi
}

setenv()
{
	ORACLE_SID=${1}
	export ORACLE_SID
	param3=${3}

	# Backuptyp
	rmanbackuptyp=${2}
	# set NLS_DATE_FORMAT for nice date-format
	export NLS_DATE_FORMAT='dd.mm.yy hh24:mi:ss'

	ORATAB=/etc/oratab

	# getting ORACLE_HOME from oratab
	ORACLE_HOME=`cat ${ORATAB} | grep "^"${ORACLE_SID}":" | cut -d":" -f2`
	# did we found the SID in oratab?
	export ORACLE_HOME

	if [ -z ${ORACLE_HOME} ]
	then
		echo "ORACLE_HOME "${ORACLE_SID}" not found in "${ORATAB}
		print_syslog "ORACLE_SID "${ORACLE_SID}" not found in "${ORATAB}
		abort_script 10
		
	fi

	if [ ! -d ${ORACLE_HOME:-"leer"} ]
	then
		# ORACLE_HOME not existing or ORACLE_SID not availible
		# => we need to exit the script!
		echo "ORACLE_HOME "${ORACLE_HOME}" not found in "${ORATAB}
		print_syslog "ORACLE_HOME "${ORACLE_HOME}" not found in "${ORATAB}
		abort_script 11
	else
		export ORACLE_HOME
	fi


	orabase=${ORACLE_HOME}/bin/orabase
	# Do we have an executable for getting the current ORACLE_BASE?
	# This script is not availible for Oracle <11g. :-(
	if [ -x ${orabase} ]
	then
		ORACLE_BASE=`${orabase}` > /dev/null
	fi

	# do we have a valid ORACLE_BASE?
	if [ ! -d ${ORACLE_BASE:-"leer"} ]
	then
		echo "We cannot work without ORACLE_BASE="${ORACLE_BASE}
		print_syslog "We cannot work without ORACLE_BASE="${ORACLE_BASE}
		abort_script 12
	fi
	export ORACLE_BASE

	# where are the rman-skripts?
	# we have the option with param3 for a dedicated directory
	if [ -d ${param3:-"leer"}  ]
	then
		# we got an existing directory as parameter 3
		# => we use that directory for searching the rman-skripts
		# => we are not using the default in $ORACLE_BASE/admin/$ORACLE_SID
		rmanskriptdir=${3}
	else
		# Do we have a rman-Skript for doing the backup?
		# The skript must be located in $ORACLE_BASE/admin/ORACLE_SID/rman/<Skript>.rman

		rmanskriptdir=${ORACLE_BASE}/admin/${ORACLE_SID}/rman
	fi

	rmanskript=${rmanskriptdir}/${rmanbackuptyp}.rman

	rmanlogdir=${rmanskriptdir}/log
	rmanlog=${rmanlogdir}/${ORACLE_SID}_${rmanbackuptyp}.log

	# Do we have 
	if [ ! ${CATALOGCONNECT:-"leer"} = 'leer' ]
	then
		check_catalog
	else
		print_syslog "Using no Catalog for Backup!"
		catalogconnect=''
	fi
}

check_requirements()
{
	if [ ! -d ${rmanlogdir} ]
	then
		echo "Directory "${rmanlogdir}" for RMAN logfiles not existing."
		print_syslog "Directory "${rmanlogdir}" for RMAN logfiles not existing."
		abort_script 21
	fi

	if [ ! -f ${rmanskript} ]
	then
		echo "RMAN-script "${rmanskript}" not existing!"
		print_syslog "RMAN-script "${rmanskript}" not existing!"
		abort_script 22
	fi

	touch ${rmanlog}
	if [ ! -f ${rmanlog} ]
	then
		echo "Logfile "${rmanlog}" for RMAN could not be created."
		print_syslog "Logfile "${rmanlog}" for RMAN could not be created."
		abort_script 23
	fi
}

do_backup()
{
	# tee, damit alle Ausgaben weg geschrieben werden.
	${ORACLE_HOME}/bin/rman \
<< _EOF_  | tee -a ${rmanlog}
	connect target /
	${catalogconnect}
@${rmanskript}
_EOF_
	retcode=${PIPESTATUS[0]}
	if [ ${retcode} -eq 0 ]
	then
		print_syslog "RMAN Backup successful. Logfile "${rmanlog}
	else
		echo "RMAN return code "${retcode}". Please check logfile "${rmanlog}
		print_syslog "RMAN return code "${retcode}". Please check logfile "${rmanlog}
		abort_script 99
	fi
	return ${retcode}
}

##############################################################################
#                                                                            #
#                                   MAIN                                     #
#                                                                            #
##############################################################################
if [ ${#} -ne 2 -a ${#} -ne 3 ]
then
	echo "rman_backup.sh <ORACLE_SID> <Backuptyp> <Directory for .rman-Files, not required>"
	exit 1
fi
print_syslog "Begin"
setenv ${*}
check_requirements
do_backup
retcode=${?}
print_syslog "End Code="${retcode}
exit ${retcode}



