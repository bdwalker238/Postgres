#!/usr/bin/env bash
#set -x

source /opt/psql/common/common_functions.sh

usage() {
echo "Usage:"
echo "${script_full}  "
exit 99
}

myhost=$(hostname -s)
returncode=0
tag="Has not been provided in command line arguments"
type1="custom"
configfile=""
pid=""
zero=0
psqlout=""
verbose="Y"

which_os

while getopts c:t:p: value
do
case $value in
t) tag=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
c) configfile=$(echo "$OPTARG") ;;
p) pid=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
*) usage ;;
esac
done

generic_vars

if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/psql_force.cfg"
fi

if [ ! -e ${configfile} ] ; then
   abort 9 "Error - Unable to locate config file ${configfile}."
fi

write_history_log "START:${script_full} for Postgres Database - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started on hostname ${myhost}"
write_log "Parameters:"
write_log " $* "
write_log "Script called with tag(-t) argumnet: ${tag}."
write_log "Read ${type1} Config file ${configfile} for configuration variables."
write_log " "

case $pid in
ALL)
    psql -d postgres -qAtXw -c "copy (SELECT datname FROM pg_database) to stdout" |egrep -v -e postgres -e template -e repmgr |while read database; do
       write_log "About to force all applications in database ${database}."
       kill_all_sql="SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${database}' AND pid <> pg_backend_pid()" 
       psql -d postgres -qAtXw -c "copy ($kill_all_sql) to stdout" 
       write_log "Forced all applications connections against ${database} successfully."
    done
    ;;
(*[0-9]*)
	pid_to_search="select count(pid) from pg_stat_activity where pid = '${pid}'"
	psqlout=$(psql -qAtXw -d postgres -c "copy ($pid_to_search) to stdout") 
	rc=$?
    if [ $psqlout -eq $zero ]; then
       write_log "No such process as ${pid}."
    else
        sql_to_kill_pid="select pg_terminate_backend(pid) from pg_stat_activity where pid = '${pid}'"
        out=$(psql -d postgres -qAtXw -c "copy (${sql_to_kill_pid}) to stdout")
        rc=$?
        if [ $rc -eq 0 ]; then
	      write_log "Successfully killed ${pid}."
        fi
    fi
    ;;	
*)  ;;
esac
write_log "Script ${script_name} completed successfully."
exit 0
