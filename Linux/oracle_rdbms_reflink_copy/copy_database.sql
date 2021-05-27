
ALTER DATABASE BACKUP CONTROLFILE TO TRACE as '/u02/test/ctl.sql' reuse resetlogs;
host sed -i 's#DB19U2#DB193#g' /u02/test/ctl.sql
host sed -i 's# ARCHIVELOG# NOARCHIVELOG#g' /u02/test/ctl.sql

alter database begin backup;

host cp --reflink -f -rp /u02/oradata/DB19U2/datafile/ /u02/oradata/DB193
host cp --reflink -f -rp /u02/oradata/DB19U2/C* /u02/oradata/DB193

alter database end backup;

alter system switch logfile;
drop restore point clonedb;
create restore point clonedb;
alter system switch logfile;
alter system switch logfile;
alter system switch logfile;
alter system archive log current;  
