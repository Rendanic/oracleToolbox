#!/bin/bash
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.com)
#
#
# parameter:
# 1   Destination directory for backups
# 2   Retention time in days for backups
#
# This script requires a bash due to ${PIPESTATUS[1]} which is not
# availible under ksh
#
# This script creates a copy of ASM SPFile and md_backup
# from Grid Infrastructure or OLR from Oracle Restart
# The script copies the last automatic OCR-Backup when running on node with that 
# backup. (New strategy. In past we created a backup and copied that file with
# problems in identifying the right node before creating the manualbackup.)
#
# This script must be run as root!
#
# The script creates a directory structure for the backups depending on 1st
# parameter.
# <backupdir>/log      Logfiles
# <backupdir>/data     created files for backups
# <backupdir>/state    statefile for log monitoring under nagios
#
# Monitoring the creation of backups:
# The script creates in <backupdir/state a file with the name ora_crs_metadata_backup.ok
# at the end of all steps. This file will be removed at the beginning. The age of file 
# must be monitored to make sure that the backup is ok.
#
# How to restore sql-script from md_backup?
# - login as oracle
# - set environment to ASM
# - uncompress backup with gunzip 
#   gunzip backup_md_backup_130112_113928.xml.gz
# - extract data for all Diskgroups to sql-file
#   asmcmd md_restore  backup_md_backup_130112_113928.xml -S export_config.sql
# - extract data for a given Diskgroup
#   same like above with additional parameter -G <Diskgroup>
#
# Changelog
# Version Date       Description
# 2.2     2016-05-25 Some more checks for error detection
#                    Better detection of Restart or Grid Infrastructure
# 2.1     2013-01-18 Bugfix for getting correct hostname at ocrconfig -showbackup
#                    new strategy: OCR-Backups won't be created anymore. We copy the last automatic file
# 2.0     2013-01-12 Rework for destination directories
#                    2 parameters added for more flexibility
#                    automatically removing of old backups
#                    do_ocrbackup rewritten
#                    Oracle-Environment not set from oraenv - sometimes getting problems...
#                    fixed problem when ASM is started with pfile 
#                     => Scripts aborts because we want ASM every time on a SPfile!
#                    Description for extract Metadata for asmcmd added
#                    added hostname to olr-backupfile
#                    write some informations to syslog with logger
# 1.0     2012-08-10 Initial Release

# Todo
# - addional error-handling when creating the destination directory
#   there was a problem in 1 environment where the destination directory could not be created and no 
#   error for debugging is availible.
# - some additions for a central directory on a shared filesystem
#   changes for the statefiles are needed when working with a shared filesystem for all cluster nodes

print_syslog()
{
	# Don't write to syslog when logger is not there
	which logger > /dev/null 2>&1
	retcode=${?}
	
	if [ ${retcode} -eq 0 ]
	then
		logger `basename $0`" "${*}
	fi
}

abort_script()
{
	print_syslog "Abort Code="${1}
	exit ${1}
}

set_env()
{
	if [ ! ${USER} = 'root' ]
	then
		echo "This script must run as root!"
		print_syslog "script must run as root!"
		abort_script 80
	fi

	if [ ${#} -eq 2 ]
	then
		OCRBACKUPCOPY=${1}
		# Retention Time for Backups in days
		OCRBACKUPPURGEDAYS=${2}
	else
		echo `basename $0`" <Backupdirectory> <Retention TIme for backups in days>"
		abort_script 81
	fi
	
	ORATAB=/etc/oratab

	# set environment from /etc/oratab
	# 1st line with +ASM will be used for CRS_HOME
	ORACLE_SID=$(grep "^+ASM" ${ORATAB} |cut -d":" -f1)
	if [ ! "${ORACLE_SID:0:4}" = '+ASM' ] 
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

	OCRLOCCFG=/etc/oracle/ocr.loc
        if [ ! -f $OCRLOCCFG ]
	then
		echo "Important configfile "$OCRLOCCFG" not found!"
		abort_script 83	
	fi

	# who is clusterwareowner?
	ORACRSOWNER=`ls -l ${ORACLE_HOME}/bin/oracle| cut -d" " -f 3`

	if [ ! -d ${OCRBACKUPCOPY} ]
	then
		# create Directory for OCRBackup if it doesn't exists
		mkdir -p ${OCRBACKUPCOPY}
		mkdir    ${OCRBACKUPCOPY}/log
		mkdir    ${OCRBACKUPCOPY}/state
		mkdir    ${OCRBACKUPCOPY}/data
		chown -R ${ORACRSOWNER} ${OCRBACKUPCOPY}
	fi
	OCRBACKUPDATADIR=${OCRBACKUPCOPY}/data
	OCRBACKUPLOGDIR=${OCRBACKUPCOPY}/log
	OCRBACKUPSTATEDIR=${OCRBACKUPCOPY}/state

	# create a unique timestamp for this run
	# This timestamp will be used for data and logfilenames
	BACKUPDATE=`date +%y%m%d_%H%M%S`

	# see header of this script for descrition of statefile
	SCRIPTSTATEFILE=${OCRBACKUPSTATEDIR}/ora_crs_metadata_backup.ok
	# we remove the file at the beginning!
	rm -f ${SCRIPTSTATEFILE}

}

do_ocrcheck()
{
	# Do we have Oracle Restart or full Grid Infrastructure?
	# read the configuration data from Oracle
	. ${OCRLOCCFG}
	
	if [ ${local_only} = 'true' ]
	then
		# We have Oracle Restart
		export ORACRS_TYPE=Restart
		echo "Oracle Restart found!" | tee -a  ${OCRBACKUPLOGDIR}/ocrcheck.log
		print_syslog "Oracle Restart found!"
	else
		# We have a full Oracle Grid Infrastructure Environment!
		export ORACRS_TYPE=GridInfra
		echo "Grid Infrastructure found!"  | tee -a ${OCRBACKUPLOGDIR}/ocrcheck.log
		print_syslog "Grid Infrastructure found!"
	fi

	OCRCHECKLOGFILE=${OCRBACKUPLOGDIR}/ocrcheck.log
	date >> ${OCRCHECKLOGFILE}
	ocrcheck >> ${OCRCHECKLOGFILE}
	retcode=${?}

	if [ ${retcode} -eq 0 ]
	then
		echo "ocrcheck is valid" | tee -a  ${OCRBACKUPLOGDIR}/ocrcheck.log
		# touch a statefile for last successful ocrcheck
		touch ${OCRBACKUPSTATEDIR}/ocrcheck.ok
	else
		echo "ocrcheck found a failure!"
		echo "can't create backup of ocr without correct ocrcheck!"
		abort_script 100
	fi
}

do_ocrbackup()
{
	# this procedure does the following steps:
	# - create a backup of local olr
	# - are we in restart or grid infrastructure?
	# - Restart => nothing more to do, there is no OCR
	# - GI => Export OCR
	#
	logfile=${OCRBACKUPLOGDIR}/olrconfig_export_`hostname`.log

	OLRFILE=${OCRBACKUPDATADIR}/backup_export_olr_`hostname`_${BACKUPDATE}
	ocrconfig -local -export ${OLRFILE}
	retcode=${PIPESTATUS[0]}
	if [ ${retcode} -eq 0 ]
	then
		echo "ocrconfig -export valid!" | tee -a ${logfile}
		echo "compressing OLR" | tee -a ${logfile}
		gzip -9 ${OLRFILE}
		touch ${OCRBACKUPSTATEDIR}/olrconfig_export.ok
		print_syslog "OLR written to "${OLRFILE}.gz
	else
		echo "ocrconfig -export failure!" | tee -a ${logfile}
		abort_script 105
	fi

	if [ ${ORACRS_TYPE} = 'GridInfra' ]
	then
		# if the filesystem for automatic backups is not change, the backups of ocr are only availible on the node who did the backups
		# which node is the starting node of this script?
		olsnodename=`olsnodes -l`

		# getting last backupentry
		lastOCRBackup=`ocrconfig -showbackup auto |sort|tail -1`

		# getting clusternode from last backup
		lastOCRBackupNode=`echo ${lastOCRBackup} | cut -d" " -f1`

		# extract filename of last backup
		ocrbackupfile="/"`echo ${lastOCRBackup} | cut -d"/" -f4-`

		echo "information from ocrconfig: "${lastOCRBackup} | tee -a ${logfile}

		# is last backupnode same like current node?
		if  [ ! ${olsnodename} = ${lastOCRBackupNode:-" "} ]
		then
			# we are not on the automatic backupnode!
			# no OCR-Backup reachable
			echo "the automtic backup was taken on "${lastOCRBackupNode}". Skipping creation of OCR-Copy!" | tee -a ${logfile}
			print_syslog "automtic backup was taken on "${lastOCRBackupNode}". Skipping creation of OCR-Copy!" 
		else
			# We are on the actual automatic backupnode
			# => we can copy the last automatic backup!
			
			# is the automatic backup existing?
			if [ ! -f  ${ocrbackupfile} ]
			then
				echo "File not found! (" ${ocrbackupfile}")"  | tee -a ${logfile}
				abort_script 191
			fi
			
			# file is existing - we can copy now
			echo "Copy OCR autobackup" | tee -a ${logfile}
			ocrbackupfilename=`basename ${ocrbackupfile}`			
			
			ocrdestfile=${OCRBACKUPDATADIR}/${ocrbackupfilename}_${BACKUPDATE}
	
			cp -v ${ocrbackupfile} ${ocrdestfile}
			retcode=${?}
			if [ ${retcode} -eq 0 ]
			then
				echo "compressing OCR" | tee -a ${logfile}
				gzip -9 ${ocrdestfile}
				echo "copy of OCR-Backup valid" | tee -a ${logfile}
				touch ${OCRBACKUPSTATEDIR}/ocrconfig_export.ok
				print_syslog "OCR backup written to "${ocrdestfile}".gz"
			else
				echo "copy of autobackup failed!" | tee -a ${logfile}
				abort_script 190

			fi

		fi # if  [ ! ${olsnodename} = ${lastOCRBackupNode:-" "} ]

	fi # if [ ${ORACRS_TYPE} = 'GridInfra' ]
	
}

do_mdbackup()
{
	echo "Creating a md_backup with asmcmd"
	MD_BACKUP_FILE=${OCRBACKUPDATADIR}/backup_md_backup_${BACKUPDATE}
	MD_BACKUP_FILELOG=${OCRBACKUPLOGDIR}/backup_md_backup.log
	su ${ORACRSOWNER} -c "date;asmcmd md_backup ${MD_BACKUP_FILE}.xml" >> ${MD_BACKUP_FILELOG}
	retcode=${?}

	if [ ${retcode} -eq 0 ]
	then
		su ${ORACRSOWNER} -c "gzip -9 ${MD_BACKUP_FILE}.xml"
		echo "md_backup succesfully created!" | tee -a ${logfile}
		touch ${OCRBACKUPSTATEDIR}/md_backup.ok
		print_syslog "md_backup written to "${MD_BACKUP_FILE}.gz	
	fi
}

do_asmspfilebackup()
{
	# create a pfile from spfile for asm
	# this backup is very useful, because we need a pfile when we lost the diskgroup
	# where oracle has storred the spfile
	#
	# The needed environment was set in set_env
	pfilename=${OCRBACKUPDATADIR}/init${ORACLE_SID}_${BACKUPDATE}.ora

# su to ORACRSOWNER needed for sqlplus. Enviroment was set in set_env
# we exit sqlplus when getting a problem. ASM must be started with a SPfile!
su ${ORACRSOWNER} -c "sqlplus -L -S / as sysasm << _EOF_
set feedback off
whenever sqlerror exit 1 rollback
create pfile='${pfilename}' from spfile;
exit
_EOF_
"
	retcode=${PIPESTATUS[0]}
	if [ ${retcode} -eq 0 ]
	then
		echo "ASM init.ora is created!"
		touch ${OCRBACKUPSTATEDIR}/backup_pfile.ok
		print_syslog "ASM-PFile written to "${pfilename}	
	else
		echo "ASM init.ora NOT CREATED!!!!!!"
		abort_script 199
	fi

}

delete_old_backups()
{
	REMOVEBACKUPFILELOG=${OCRBACKUPLOGDIR}/backup_remove_old.log
	# OCRBACKUPPURGEDAYS must be greater then 0 because -1 will remove ALL backups. :-(
	if [ ${OCRBACKUPPURGEDAYS} -lt 0 ]
	then
		echo "Retention time for backups must be greater then 0"
		echo "aborting script!"
		abort_script 110
	fi
	# this procedure removes old backups depending on OCRBACKUPPURGEDAYS
	echo "Deleting backups older then "${OCRBACKUPPURGEDAYS}" days" | tee -a ${REMOVEBACKUPFILELOG}
	# Removing ASM-PFiles
	find ${OCRBACKUPDATADIR} -name "init+ASM*_??????_??????.ora" -ctime +${OCRBACKUPPURGEDAYS} -type f -exec rm -vf {} \; | tee -a ${REMOVEBACKUPFILELOG}
	# Removing MD_Backups
	find ${OCRBACKUPDATADIR} -name "backup_md_backup_??????_??????.xml.gz" -ctime +${OCRBACKUPPURGEDAYS} -type f -exec rm -vf {} \; | tee -a ${REMOVEBACKUPFILELOG}
	# Removing OLR
	find ${OCRBACKUPDATADIR} -name "backup_export_olr_`hostname`_??????_??????.gz" -ctime +${OCRBACKUPPURGEDAYS} -type f -exec rm -vf {} \; | tee -a ${REMOVEBACKUPFILELOG}
	# Removing OCR
	find ${OCRBACKUPDATADIR} -name "backup??.ocr_??????_??????.gz" -ctime +${OCRBACKUPPURGEDAYS} -type f -exec rm -vf {} \; | tee -a ${REMOVEBACKUPFILELOG}
}
##########################################################################################
##########################################################################################
#                                                                                        #
#                                 Main                                                   #
#                                                                                        #
##########################################################################################
##########################################################################################

print_syslog "Begin"
set_env ${*}
date | tee -a ${logfile}
do_ocrcheck
do_ocrbackup
do_asmspfilebackup
do_mdbackup
delete_old_backups
# no exit with error from a subroutine
# => all went fine, creating a final statefile
touch ${OCRBACKUPSTATEDIR}/ora_crs_metadata_backup.ok
date | tee -a ${logfile}
print_syslog "End Code=0"

