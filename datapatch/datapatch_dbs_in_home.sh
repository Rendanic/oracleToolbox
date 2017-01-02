#!/bin/bash
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# Date: 02.01.2017

# This script is for applying Oracle Patches in Databases with datapatch
# Please keep in mind, that this only works with Oracle from 12c onwards.
#
# How it works:
# - check for environment
# - check for running database
# - startup open when Instance is not startet
# - datapatch -prereq
# - restart Instance when patches must be applied
# - apply patches with datapatch
# - restart Instance when patches were applied

# Restrictions:
# - Special requirements for real Grid-Infrastructure
#   All Database must be running with 'cluster_database=true'
# - only for Database Version >= 12.1 
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

if [ $# -ne 1 ] ; then
    echo "$(basename $0) <ORACLE_HOME>"
    exit 10
fi

patch_home=$1

check_crs(){

    # we could be on Grid-Infrastructure
    # => There is only an entry for the DB_NAME in oratab!
    # => We need to find the right ORACLE_SID from Clusterware
    OCRLOC=/etc/oracle/ocr.loc
    CRS_TYPE=""

    echo "Check for Grid-Infrastructure / Restart"
    if [ -f $OCRLOC ]
    then
            CRS_TYPE=cluster
            . $OCRLOC
            . /etc/oracle/olr.loc
            export crs_home
            export crs_home
            crs_local=$(echo ${local_only} | tr '[:upper:]' '[:lower:]')

        if [ ${crs_local:-"true"} = 'false' ]
        then
            echo "Grid-Infrastructure found"
            CRS_TYPE=cluster
        else
            echo "Oracle Restart found"
            CRS_TYPE=restart
        fi
    else
            echo "Single Instance found"
    fi
    echo "#################################################"
    export CRS_TYPE
}

get_sid_crs(){
    ORACLE_SID=$(${SRVCTL} status instance -d ${ORACLE_SID} -node $(${crs_home}/bin/olsnodes -l) | cut -d" " -f2)
    echo "Setting new ORACLE_SID from CRS: "$ORACLE_SID
    export ORACLE_SID
}

check_environment(){
    echo "#################################################"
    echo "Doing some prechecks before starting the work"

    # check if user executing this script is owner of Oracle
    echo "ORACLE_HOME: "${patch_home}
    oracleexe=${patch_home}/bin/oracle
    if [ ! -x ${oracleexe} ] ; then
        echo "oracle is not found in "${oracleexe}
        exit 1
    fi

    echo "Check owner of Oracle"
    oracleowner=$(ls -l ${oracleexe}| awk '{print $3}')
    if [ ! $(id -un) = $oracleowner ] ; then
        echo "Please execute this scipt as $oracleowner"
        echo "Current user: "$(id -un)
        echo "ORACLE_HOME : " ${patch_home}
        exit 2
    fi
}

restart_db_crs() {
    startmode=$1
    clustermode=${2:-"false"}
    echo "Check state with srvctl"
    $SRVCTL status database -d $DB_NAME
    echo "Stop Instances on every node"
    $SRVCTL stop database -d $DB_NAME
    echo "Set cluster_database to "$clustermode
    # try to start the database
    $ORACLE_HOME/bin/sqlplus -S -L /nolog  << _EOF
conn / as sysdba
startup nomount quiet
show parameter cluster_database
alter system set cluster_database=$clustermode scope=spfile;
shutdown immediate
startup $startmode quiet
show parameter cluster_database
_EOF
}



restart_db(){
    mode=${1:-""}
    echo "#################################################"
    echo "Restart Oracle Database "$mode
    echo "#################################################"
    # check for pmon
    ps -elf | grep " ora_pmon_"$ORACLE_SID"$" > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        shutdowndb="shutdown immediate"
    else
        shutdowndb=""
    fi

    # try to start the database
    $ORACLE_HOME/bin/sqlplus -S -L /nolog  << _EOF
conn / as sysdba
PROMPT $shutdowndb
$shutdowndb
prompt startup $mode
startup $mode quiet
_EOF
}

check_open_database(){
    echo "#################################################"
    echo "Checking for running database and starting it"
    echo "#################################################"
    $ORACLE_HOME/bin/sqlplus -S -L /nolog  >/dev/null<< _EOF
whenever sqlerror exit 1
conn / as sysdba
set termout off feedback off
select count(1) from dba_users;
_EOF

    if [ $? -ne 0 ] ; then
        # try to start the database
        restart_db " "
    fi
}

check_datapatch(){
    ORACLE_SID=$1
    echo "#################################################"
    echo "Check for Patches with datapatch"
    echo "#################################################"
    datapatchout=$($DATAPATCH -verbose -prereq -upgrade_mode_only -db $ORACLE_SID)
    retcode=$?
    if [ $? -ne 0 ] ; then
        echo "datapatch returned with returncode <> 0!"
        return 99
    fi

    echo -e "$datapatchout"
    # Search for result
    echo -e "$datapatchout" | grep "Bootstrap timed out after " > /dev/null
    if [ $? -eq 0 ] ; then
        return 10
    fi
    echo -e "$datapatchout" | grep "The database must be in upgrade mode" > /dev/null
    if [ $? -eq 0 ] ; then
        return 2
    fi
    echo -e "$datapatchout" | grep "not installed in the SQL registry" > /dev/null
    if [ $? -eq 0 ] ; then
        return 1
    else
        echo -e "$datapatchout" | grep "Nothing to apply" > /dev/null
        if [ $? -eq 0 ] ; then
            return 0
        fi
    fi

    # Nothing to apply
    retval=$?
    echo "Return-Code: "$retval
}

do_datapatch(){
    echo "#################################################"
    echo "Execute datapatch for ORACLE_SID "$1
    echo "#################################################"
    $DATAPATCH -verbose -db $1 ${2:-""}
}


check_environment

check_crs

IFS=$'\n'
for sid in $(cat /etc/oratab | grep -v "^#" | grep "^[a-zA-Z]") ; do

    export ORACLE_SID=$(echo $sid | cut -d":" -f1)
    export ORACLE_HOME=$(echo $sid | cut -d":" -f2)

    # DB_NAME is needed when running on Grid-Infrastructure for srvctl
    export DB_NAME=$ORACLE_SID

    DATAPATCH=$ORACLE_HOME/OPatch/datapatch
    SRVCTL=$ORACLE_HOME/bin/srvctl

    echo "#################################################"
    echo "Working on ORACLE_SID: "$ORACLE_SID
    if [ ! $patch_home = $ORACLE_HOME ] ; then
        continue
    else
        # get ORACLE_SID from Clusterware when Grid-Infrastructure is used
        # => GI only stores the DB_NAME as SID in oratab!
        # added SIDs without Resource will skip this loop
        # => Ignore added SIDs in oratab for Instances in GI
        if [ ${CRS_TYPE:-"unknown"} = 'cluster' ] ; then

            # we are on a real Grid-Infrastructure
            # is this ORACLE_SID a DB_NAME or a fakename for easy handling of oraenv?
            $SRVCTL config database -d $ORACLE_SID >/dev/null
            if [ $? -ne 0 ] ; then
                echo "Skipping this ORACLE_SID as it is not a real dateabase in oratab!"
                continue
            fi
            # get current ORACLE_SID on host from Grid-Infrastructure for this Instance
            get_sid_crs 

        elif [ ${CRS_TYPE:-"unknown"} = 'restart' ] ; then

            $SRVCTL config database -d $ORACLE_SID >/dev/null
            if [ $? -ne 0 ] ; then
                echo "Skipping this ORACLE_SID as it is not a real dateabase in oratab!"
                continue
            fi

        else

            # Single-Instance
            # => Check for init.ora ora spfile.ora
            if [ -f $ORACLE_HOME/dbs/init${ORACLE_SID}.ora -o -f $ORACLE_HOME/dbs/spfile${ORACLE_SID}.ora ] ; then
                echo "Parameterfile for Single-Instance found"
            else
                echo "Skipping this ORACLE_SID as it is not a real dateabase in oratab!"
                continue
            fi

        fi

        check_open_database
        check_datapatch $ORACLE_SID
        retval=$?

        # returncodes:
        #  0 = nothing to do
        #  1 = datapatch 'normal'
        #  2 = datapatch 'upgrade' mode
        # 10 = Bootstrap failure
        # 99 = Returncode <>0 from datapatch

        if [ $retval -eq 0 ] ; then
            echo "Nothing to apply!"
            continue

        elif [ $retval -eq 10 ] ; then
            echo "#################################################"
            echo "-------------------------------------------------"
            echo "Bootstrap Failure. Cannot get patch information. Aborting installation for this Database!"
            echo "Mostly a restart help to skip this problem. The real reason is not known at the moment."
            echo "-------------------------------------------------"
            echo "#################################################"
            continue

        elif [ $retval -eq 1 ] ; then

            echo "#################################################"
            echo "doing normal datapatch apply"
            echo "#################################################"
            do_datapatch $ORACLE_SID

            echo "#################################################"
            echo "final check after datapatch"
            check_datapatch $ORACLE_SID

        elif [ $retval -eq 2 ] ; then

            echo "#################################################"
            echo "Restarting Database in Upgrade mode"
            echo "#################################################"
            if [ ${CRS_TYPE:-"unknown"} = 'cluster' ] ; then
                echo "Restart RAC Database"
                restart_db_crs "upgrade exclusive" false
                do_datapatch $ORACLE_SID
                restart_db_crs nomount true
                $SRVCTL stop database -d $DB_NAME
                $SRVCTL start database -d $DB_NAME
            else
                restart_db "upgrade exclusive"
                do_datapatch $ORACLE_SID
                restart_db " "
            fi
            echo "#################################################"
            echo "final check after datapatch"
            check_datapatch $ORACLE_SID

        fi
    fi
done
