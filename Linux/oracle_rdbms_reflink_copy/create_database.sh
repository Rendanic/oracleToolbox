#!/bin/bash

ORACLE_SID=db193
export ORACLE_SID

echo "shutdown abort" | sqlplus / as sysdba

sqlplus / as sysdba << _EOF_

create pfile from spfile;
host sed '/db_name=/d' ${ORACLE_HOME}/dbs/initdb193.ora
host echo "db_name=db19" >> ${ORACLE_HOME}/dbs/initdb193.ora

host sed -i "s#db_name=\'dbclone\'#db_name=\'db19\'#g" ${ORACLE_HOME}/dbs/initdb193.ora

create spfile from pfile;
startup nomount QUIET
SET AUTORECOVERY ON

@@ctl.sql
host echo "catalog start with '/u02/fra/DB19U2/archivelog' noprompt;" | rman target /
RECOVER DATABASE using backup controlfile until cancel
PROMPT alter database open resetlogs;
alter database open resetlogs;
@@ctl.sql

PROMPT shutdown immediate
shutdown immediate
_EOF_
