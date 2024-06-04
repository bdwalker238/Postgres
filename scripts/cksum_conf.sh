#!/bin/bash
#set -x
# Script to record cksums of core Postgres configuration files on a periodically
# Date : 04/06/2024
# Version :  1.0  # First Release
# version :  1.1  Add Logic to compare in-memory pg_hba md5sum to script.
# Version :  1.2 Add "Select pg_conf_load_time() > modification FROM pg_stat_file('pg_hba.conf');"
#
# Purpose - To monitor changes to Postgres , Vacuum age
# Author : Brian Walker

usage() {

echo  "Usage $0 <-c file>/No arguments"
echo  "dba_dir =  working directory for script tmp and output file's e.g. DBADIR=\"/psql/dba\""
echo  " "
echo  "Additional further default options can be specified in the configuration file, located at ~/cfg/pgconfig_check.cfg"
echo  "FILE1=<ConfigFile>"
echo  "FILE2=<ConfigFile"
echo  "FILEN=<ConfigFile>"
echo  "DBADIR=<Location>"
exit 99
}

write_log() {
dt=`date +%Y-%m-%d-%H-%M.%S`
$echoe "$dt - ${my_pid}\t-$1 " >> ${log_main}
$echoe "$dt - ${my_pid}\t-$1 "
}

write_history_log() {
dt=`date "+%a %d %b %Y %H:%M:%S"`
$echoe "$dt ${my_pid}\t: $1" >>${dba_log_dir}/postgres_history.log
}

abort() {
   write_log "$2"
   write_log "${script_name} ended abnormally"
   write_history_log "${script_full} for instance ${inst} - ended abbormally"
   echo $2
   exit $1
}


generic_vars() {
my_pid=$$
my_random=$RANDOM
my_random2=$RANDOM
script_name=$(basename ${0%.*})
script_full=$(basename $0)
script_date=$(date +%Y%m%d%H%M)
inst_home_dir=$(echo ~)
dba_log_dir=${dba_dir}/logs
dba_tmp_dir=${dba_dir}/tmp
mkdir -p ${dba_tmp_dir}
rc=$?
if [[ $rc -ne 0 ]]; then
	  echo "Error - Unable to create directory ${dba_log_dir}. Need a working area for script to run!"
	  exit 14
fi
mkdir -p ${dba_log_dir}
tmp_file=${dba_tmp_dir}/${script_name}_${my_pid}_${my_random}_${my_random2}.tmp
touch ${tmp_file}
rc=$?
if [[ $rc -ne 0 ]]; then
        echo "Error - Unable to create temp file ${tmp_file}. Need a working area for script to run!"
        exit 16
fi
my_random=$RANDOM
my_random2=$RANDOM
tmp2_file=${dba_tmp_dir}/${script_name}_${my_pid}_${my_random}_${my_random2}.tmp
touch ${tmp2_file}
rc=$?
if [[ $rc -ne 0 ]]; then
   echo "Error - Unable to create temp file ${tmp2_file}. Need a working area for script to run!"
   exit 16
fi
log_main_name=${script_name}_${script_date}.log
log_main=${dba_log_dir}/${log_main_name}
}


pg_hba() {

 local tocheck="SELECT pg_conf_load_time() > modification FROM pg_stat_file('pg_hba.conf')"
 local haschanged=""
 write_log "Recording in memory md5sum for pg_hba as "
 in_memory_hba=$(psql ${_runas} -qAtXw -c "copy (select md5(pg_read_file((select setting from pg_settings where name = 'hba_file')))) to stdout")
 write_log "select md5(pg_read_file((select setting from pg_settings where name = 'hba_file'))) = "
 write_log "md5sum = ${in_memory_hba}"
 write_log " "
 haschanged=$(psql ${_runas} -d postgres --single-transaction -c "${tocheck}" -A -F ',' -q -t -X -w |tr [a-z] [A-Z])  
 if [ "$haschanged" = "T" ]; then
  write_log "IMPORTANT -> The pg_hba.conf file has not changed !"
 else
  write_log "The pg_hba.conf file has changed a \"SELECT pg_reload_conf();\" is required."
 fi

}


read_config_file() {

dba_dir=$(cat ${config} |grep -i "^DBADIR" | cut -f2 -d= |tr -d '"' | awk ' {print $1} ' |tr [a-z] [A-Z])
if [[ "${dba_dir}" = "" ]]; then 
  inst_dir="/psql"
  dba_dir=${inst_dir}/dba
fi
if [[ -d ${dba_dir} ]]; then
   generic_vars
else
   echo "Error - Directory ${dba_dir} not valid!"
   exit 5
fi
file_count=$(cat ${config} |grep -i "^FILE" | cut -f2 -d= |tr -d '"' | awk ' {print $1} '|wc -l)
if [[ ${file_count} -eq 0 ]]; then
  echo "Error No files specified in configuration file ${config}."
  usage
fi
while read -r line; 
do
  file=$(echo ${line} | grep -i "^FILE" | cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
  if [[ -f ${file} ]]; then
     echo "$file" >> ${tmp_file}
  else
     echo "Error File ${file} from config file ${config} does not exist!"
     exit 4
  fi
done <${config}

}

verify_pgdata() {
 do_i_exist="${PGDATA}/postgresql.conf"
   if [[ -f ${do_i_exist} ]]; then
       echo "${do_i_exist}" >>${tmp_file}
       _pgconfigfile=$do_i_exist
   else
       echo "Unable able to find ${do_i_exist}"
        exit 6
   fi
   do_i_exist="${PGDATA}/pg_hba.conf"
   if [[ -f ${do_i_exist} ]]; then
       echo "${do_i_exist}"  >>${tmp_file}
       _pghbafile=$do_i_exist
   else
      echo "Unable able to find ${do_i_exist}"
      exit 7
   fi
   if [[ ! -z "${PGPPORT}" ]]; then
      grep "^port" ${_pgconfigfile} >/dev/null
      rc=$?
      if [ $rc -eq 0 ]; then
        _port=$(grep "^port" ${_pgconfigfile}|awk -F= ' {print $2} '|tr -d ' ')
      else
        abort 10 "Error - Unable to detect PG port number"
      fi
   else
	_port=$PGPORT
   fi
   # - Remove any duplicate config files to check MD5sum.
   sort -u ${tmp_file} >${tmp2_file}
   cat ${tmp2_file}>${tmp_file} && rm -f ${tmp2_file}
}


verify_postgres() {
  if [[ ! -v PGDATA ]]; then
    echo "Error detecting PGDATA. Please check it is set"
    exit 3
  fi
}



########## Start of Main Code

sshcommand="/usr/bin/ssh"
md5sumcommand="/usr/bin/md5sum"
whoamicommand="/usr/bin/whoami"
config=""
log_dir=""
inst_dir=""
dba_dir=""
tmp_dir=""
_pgconfigfile=""
_pghbafile=""
_port=""
_runas="-U postgres" 
background="no"

case $(uname) in 
Linux) echoe="echo -e"	;;
AIX)	echoe="echo"    ;;
*)	echoe=""        ;;
esac


while getopts "c:h:d:" value 
do
  case $value in
  c) config="$OPTARG" ;;
  h) usage ;;
  d) background=yes ;;
  *) usage ;;
esac
done

if [[ "$config" = "" ]]; then
  config="/psql/home/cfg/pgconfig_check.cfg"
fi

if [ $background = "yes" ]; then
  $0 -c $config < /dev/null &> /dev/null &
  disown 
  exit 0
fi

inst=$(${whoamicommand})
verify_postgres



if [[ -f $config ]];  then
   read_config_file
   verify_pgdata
elif  [[ ! -z ${PGDATA} ]];  then
  inst_dir="${HOME}"
  script_name=$(basename ${0%.*})
  dba_dir=${inst_dir}/${script_name}_output
  generic_vars
  verify_pgdata
  config="NO Config file specified!"
else

   echo "Error Unable to read file ${config} or detect a valid PGDATA variable."
   exit 1
fi

write_history_log "${script_full} for Postgres - started with Pid $my_pid"
write_log "-----------------------------------------------------------------------"
write_log "${script_name} script started  with pid $my_pid."
write_log "Parameters:"
write_log " $* "
write_log "    "
write_log " Total Parameters passed $# to ${script_name}."
write_log "Script will check and record md5sum values of custom/environment Postgres files from configuration file - ${config}."
write_log "Script has detected a valid Postgrea Data directory ${PGDATA}."
write_log "Script is been run as Linux user ${USER}."
write_log " "
cat ${tmp_file} |while read line; do
  output=$(${md5sumcommand} ${line})
  write_log " md5sum ${line}"
  write_log " $output"
  write_log " "
done

write_log " "
write_log "Recording File md5sum's Finished."
write_log "List Postgres compile options"
write_log "Issue command -  pg_config --configure "
output=$(pg_config --configure)
write_log "$output"
write_log "Output of pg_config complete"
write_log "Testing if Postgres is accepting connection's locally as user ${USER} via host 'localhost'@${_port}."
write_log "Issue command : - pg_isready -h localhost -p ${_port} -U ${USER} -"
_accept=$(pg_isready -h localhost -p ${_port} -U ${USER})
rc=$?
if [ $rc -eq 0 ]; then
	write_log "${_accept}"
	write_log " "
	pg_hba
	write_log "Vaccuum section."
	write_log "Issuing sql -  select count(*) from pg_stat_activity where backend_type = 'autovacuum worker'."
	_curr_vac_workers=$(psql -qAtXw -c "copy (select count(*) from pg_stat_activity where backend_type = 'autovacuum worker') to stdout")
	write_log "Current running autovacuum worker's are equal to  ${_curr_vac_workers}."
	write_log "Issue SQL - select max(age(datfrozenxid)) from pg_database"
	_curr_freeze_age=$(psql -qAtXw -c "copy (select max(age(datfrozenxid)) from pg_database) to stdout")
	write_log "Current autovacuum freeze age = $_curr_freeze_age"
	write_log "Vaccuum overall settings ( excluding specfic to a table) are : - "
	write_log "Name			Setting		Unit"
        psql -qAtXw -c "copy (select name, setting, unit from pg_settings where name  ~ 'autovacuum|vacuum.*cost' order by 1) to stdout" | while IFS=$'\t' read -r name setting unit; do 

	unit=$(echo $unit | sed 's|\N|NULL|g')
	write_log "$name			$setting	$unit"; 
        done
	write_log "End Vaccuum Settings."
	write_log "Get Database Transaction id ( Burn Rate) SELECT * FROM txid_current()"
	_current_transaction_id=$(psql -qAtXw -c "copy (SELECT * FROM txid_current()) to stdout")
        write_log "Out of SELECT * FROM txid_current() is $_current_transaction_id."
	write_log "Get Information about standbys."
        write_log "Get XMIN of Standbys"
        _standbys=$(psql -qAtXw -P 'null=NULL' -c "copy(SELECT pid, datname, usename, state, backend_xmin FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC) to stdout")
        write_log "Standby Information: ${_standbys}"
	write_log "Issue command to discover lag SELECT  CASE WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()
        THEN 0
        ELSE EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp())
        END AS log_delay"
	_lag=$(psql -qAtXw -c "copy (SELECT  CASE WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() THEN 0 ELSE EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp()) END AS log_delay) to stdout")
	write_log "Current lag is ${_lag}"


else
	write_log "Error - Postgres doesn't appear to be up on port ${_port}."
	write_log "Command - pg_isready -h localhost -p ${_port} -U ${USER} returned"
	write_log "${_accept}"
fi	
	write_log "Delete tmp file ${tmp_file}"
rm -f ${tmp_file}
write_log "Delete tmp files finished."
write_log "Script ${script_name} with pid $my_pid Finished Successfully"
write_history_log "${script_full} with pid $my_pid for Postgres - End Successfully"
exit 0
