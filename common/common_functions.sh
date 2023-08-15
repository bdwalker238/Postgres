#!/usr/bin/env bash
#
#
# commonfunctions.sh  .  Should have permissions 644

 
echoe=""

which_os() {
  case $(uname) in 
  Linux ) echoe="echo -e"	;;
  AIX)	echoe="echo" ;;
  *)	echoe="" ;;
  esac
}

generic_vars() {

my_pid=$$
script_name=$(basename ${0%.*})
script_full=$(basename $0)
script_date=$(date +%Y%m%d)
script_time=$(date +%H%M%S)
inst_dir=/psql
inst_home=${inst_dir}/home
dba_dir=${inst_dir}/dba
dba_log_dir=${dba_dir}/logs
dba_tmp_dir=${dba_dir}/tmp

if  [ ! -e  $dba_log_dir ]; then
  echo "Error - Script Abort - No log directory $dba_log_dir present "
  exit 2
fi

if  [ ! -e  $dba_tmp_dir ]; then
  mkdir -p ${dba_tmp_dir}
fi

log_main_name=${script_name}_${script_date}_${script_time}.log
log_main=${dba_log_dir}/${log_main_name}
history_log=${dba_log_dir}/postgres_history.log
touch $log_main
touch $history_log
chown postgres:postgres $log_main
chown postgres:postgres $history_log
chmod 644 $log_main
chmod 644 $history_log
}


write_log() {
dt=$(date +%Y-%m-%d-%H-%M.%S)
$echoe "$dt - ${my_pid}\t-$1" >> ${log_main}
if [ "$verbose" = 'Y' ];  then
  $echoe "$dt - ${my_pid}\t-$1"
fi
}

write_history_log() {
dt=$(date "+%a %d %b %Y %H:%M:%S")
$echoe "$dt ${my_pid}\t: $1" >>${history_log}
}

abort() {
   write_log "$2"
   write_log "${script_name} ended abnormally"
   write_history_log "${script_full} for Postgres - ended abbormally"
   echo $2
   exit $1
}
