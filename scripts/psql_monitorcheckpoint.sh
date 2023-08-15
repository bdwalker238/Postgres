#!/usr/bin/env bash
#set -x
#
# Version 1
#
#  Description .  Schedule this script to run periodically every first mnute of every 1 hour 
# to determine  number of checkpoints_timed , checkpoints_req are occuring.  Using the Output 
# over a  course of a week/month .  Tune max_wal_size, checkpoint_timeout, checkpoint_completion_target 
# to meet workload requirements. 


which_os() {
  case $(uname) in 
  Linux ) echoe="echo -e"	;;
  AIX)	echoe="echo" ;;
  *)	echoe="" ;;
  esac
}

write_history_log() {
dt=$(date "+%a %d %b %Y %H:%M:%S")
$echoe "$dt ${my_pid}\t: $1" >>${history_log}
}



usage() {
echo "Usage:"
echo "${script_full}  "
exit 99
}

echoe=""
configfile=""
checkpointsql="SELECT CURRENT_TIME, checkpoints_timed, checkpoints_req FROM pg_stat_bgwriter"
resetsql="SELECT pg_stat_reset_shared('bgwriter')"
script_name=$(basename ${0%.*})
script_full=$(basename $0)
script_date=$(date +%Y%m%d)
inst_dir=/psql
dba_dir=${inst_dir}/dba
dba_log_dir=${dba_dir}/logs
dba_tmp_dir=${dba_dir}/tmp



which_os

while getopts c: value
do
case $value in
c) configfile=$(echo "$OPTARG") ;;
*) usage ;;
esac
done

if  [ ! -e  $dba_log_dir ]; then
  echo "Error - Script Abort - No log directory $dba_log_dir present "
  exit 2
fi

if  [ ! -e  $dba_tmp_dir ]; then
  mkdir -p ${dba_tmp_dir}
fi

log_main_name=${script_name}_${script_date}.log
log_main=${dba_log_dir}/${log_main_name}
history_log=${dba_log_dir}/postgres_history.log
touch $log_main
touch $history_log
chown postgres:postgres $log_main
chown postgres:postgres $history_log
chmod 644 $log_main
chmod 644 $history_log




if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/psql_monitorcheckpoint.cfg"
fi

if [ ! -e ${configfile} ] ; then
   abort 9 "Error - Unable to locate config file ${configfile}."
fi

write_history_log "START:${script_full} for Postgres Database - started."

[ -s $log_main ] ||  
{ 
    echo "Time[with timezone],checkpoints_timed,checkpoints_req." >$log_main; 
  # psql -d postgres -qAtXw -c "copy (${resetsql}) to stdout" 
} 
psql -d postgres --single-transaction -c "${checkpointsql}" -A -F ',' -q -t -X -w >>$log_main

write_history_log "END:${script_full} for Postgres Database - ended."
exit 0