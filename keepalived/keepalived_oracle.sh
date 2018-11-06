#!/bin/bash
#
# Date: 06.11.2018
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# This is a helper for keepalived to manage VIPs for Oracle Databases
# Common use is for Primary- / Standby-Databases with a VIP for
# connect to Oracle, because there are still stupid applications who
# could not use the failover configuration from SQLNet...
#
# Parameter:
# - filename for configuration file
#
# example for configuration file:
# db_user=c##keepalived
# db_password=topsecret
# db_port=1521
# db_service=testdb


# Why ORACLE_SID and DB-Servicename?
# The ORACLE_SID is only used for setting the ORACLE_HOME.
# DB-Service should be point to a service who is only online
# when the database is in PRIMARY-Role.

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

configfile=${1}

set_env(){
  for ORACLE_HOME  in $(cat /etc/oratab | grep "^[a-zA-Z]" | cut -d":" -f2) ; do
    SQLPLUS=${ORACLE_HOME}/bin/sqlplus
    if [ -x $SQLPLUS ] ; then
      echo "ORACLE_HOME: "$ORACLE_HOME
      export ORACLE_HOME SQLPLUS
      return
    fi
  done
}

read_config(){
  if [ -f ${configfile} ] ; then
    . ${configfile}

    export db_user db_password db_port db_service
  else
    echo "missing configuration file: "${configfile}
    exit 99
  fi
}
check_login(){
  db_connect=localhost:${db_port}/${db_service}
  echo "Login as ${db_user} to ${db_connect}"

  output=$(${SQLPLUS} -L -S /NOLOG <<_EOF_
whenever sqlerror exit 10 rollback
set lines 2000
set pages 0
set trimspool on
set heading off
conn ${db_user}/${db_password}@${db_connect}
SELECT SYS_CONTEXT ('USERENV', 'DB_NAME') FROM DUAL;
SELECT 'on ' || SYS_CONTEXT ('USERENV', 'HOST') FROM DUAL;
_EOF_
)
retcode=$?
echo $output
exit ${retcode}
}


set_env
read_config
check_login
exit $?
