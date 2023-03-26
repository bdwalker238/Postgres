#!/usr/bin/env bash
#set -x

source /opt/psql/common/common_functions.sh

usage() {
echo "Usage:"
echo "${script_full}  "
exit 99
}

myhost=$(hostname -s)
tag="Has not been provided in command line arguments"
type1="custom"
configfile=""
terminatestring="pg_cancel_backend"
pid=""
zero=0
pidmessage1=""
dbmessage1="About to force all applications with ${terminatestring}."
dbmessage2="Forced off all applications connections successfully with $terminatestring."
force="no"
psqlout=""
verbose="Y"

which_os

while getopts c:t:p:f: value
do
case $value in
t) tag=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
c) configfile=$(echo "$OPTARG") ;;
p) pid=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
f) force=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
*) usage ;;
esac
done

pidmessage1="Successfully killed ${pid} gracefully."

generic_vars

if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/psql_cancel.cfg"
fi

if [ ! -e ${configfile} ] ; then
   abort 9 "Error - Unable to locate config file ${configfile}."
fi

write_history_log "START:${script_full} for Postgres Database - started."
write_log "-------------------------------------------------------------------"
write_log "${script_name} started on hostname ${myhost}"
write_log "Parameters:"
write_log " $* "
write_log "Script called with tag(-t) argumnet: ${tag}."
write_log "Read ${type1} Config file ${configfile} for configuration variables."
write_log " "

if [ "$force" = "YES" ]; then
    terminatestring="pg_terminate_backend"
    dbmessage1="About to force all applications with ${terminatestring}."
    dbmessage2="Forced off all applications connections successfully with $terminatestring."
    pidmessage1="Successfully killed ${pid}."
fi



case $pid in
ALL)
    psql -d postgres -qAtXw -c "copy (SELECT datname FROM pg_database where datname NOT in ('repmgr','template0','template1')) to stdout" |while read database; do
       write_log "${dbmessage1}"
       kill_all_sql="SELECT ${terminatestring}(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${database}' AND pid <> pg_backend_pid()" 
       psql -d postgres -qAtXw -c "copy ($kill_all_sql) to stdout" 
       write_log "${dbmessage2}"
    done
    ;;
(*[0-9]*)
	pid_to_search="select count(pid) from pg_stat_activity where pid = '${pid}'"
	psqlout=$(psql -qAtXw -d postgres -c "copy ($pid_to_search) to stdout") 
	rc=$?
    if [ $psqlout -eq $zero ]; then
       write_log "No such process as ${pid}."
    else
        sql_to_kill_pid="select ${terminatestring}(pid) from pg_stat_activity where pid = '${pid}'"
        out=$(psql -d postgres -qAtXw -c "copy (${sql_to_kill_pid}) to stdout")
        rc=$?
        if [ $rc -eq 0 ]; then
	      write_log "${pidmessage1}"
        fi
    fi
    ;;	
*)  ;;
esac
write_log "Script ${script_name} completed successfully."
write_history_log "FINISHED:${script_full} for Postgres Database."
exit 0
