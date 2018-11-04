#
#
#
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

  ${ORACLE_HOME}/bin/sqlplus -L -S /NOLOG <<_EOF_
whenever sqlerror exit 10 rollback
conn ${db_user}/${db_password}@${db_connect}
_EOF_
exit ${?}
}


#check_pmon
set_env
check_login
exit $?
