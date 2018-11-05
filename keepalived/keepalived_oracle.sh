#!/bin/bash
#
# Date: 04.11.2018
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# This is a helper for keepalived to manage VIPs for Oracle Databases
# Common use is for Primary- / Standby-Databases with a VIP for
# connect to Oracle, because there are still stupid applications who
# could not use the failover configuration from SQLNet...
#
# Parameter:
# - ORACLE_SID
# - DB-User with 'create session' and 'select on v$database'
# - DB-Password
# - Listener-Port
# - DB-Servicename
#
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

ORACLE_SID=${1}
db_user=${2}
db_password=${3}
db_port=${4:-1521}
db_service=${5:-${1}}

set_env(){
  ORACLE_HOME=$(cat /etc/oratab | grep "^${ORACLE_SID}:" | cut -d":" -f2)
  echo "ORACLE_HOME: "$ORACLE_HOME
  export ORACLE_HOME
}

check_login(){
  db_connect=localhost:${db_port}/${db_service}
  echo "Login as ${db_user} to ${db_connect}"

  output=$(${ORACLE_HOME}/bin/sqlplus -L -S /NOLOG <<_EOF_
whenever sqlerror exit 10 rollback
set lines 2000
set pages 0
set trimspool on
set heading off
conn ${db_user}/${db_password}@${db_connect}
select database_role from v\$database;
_EOF_
)
retcode=$?
echo $output
exit ${retcode}
}


#check_pmon
set_env
check_login
exit $?
