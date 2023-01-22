#!/bin/bash
#set -x


usage() {

exit 99
}


write_log() {
dt=`date +%Y-%m-%d-%H-%M.%S`
$echoe "$dt - ${my_pid}\t-$1" >> ${log_main}
$echoe "$dt - ${my_pid}\t-$1"
}

write_history_log() {
dt=`date "+%a %d %b %Y %H:%M:%S"`
$echoe "$dt ${my_pid}\t: $1" >>${history_log}
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
script_name=$(basename ${0%.*})
script_full=$(basename $0)
script_date=$(date +%Y%m%d)
inst_dir=/psql
inst_home=${inst_dir}/home
dba_dir=${inst_dir}/dba
dba_log_dir=${dba_dir}/logs
log_main_name=${script_name}.${script_date}.log
log_main=${dba_log_dir}/${log_main_name}
history_log=${dba_log_dir}/postgres_history.log
touch $log_main
touch $history_log
chown postgres:postgres $log_main
chown postgres:postgres $history_log
#DBNAME=`echo ${DBNAME} |tr '[a-z]' '[A-Z]'`
}

configfile=""
detail=""
timestamp=""
success=0
netmask=""
type1=""
node=""
primary=""
conninfo=""
sprimary=""
event=""

case $(uname) in 
Linux ) echoe="echo -e"	;;
AIX)	echoe="echo" ;;
*)	echoe="" ;;
esac

# ifconfig ens3:0 inet 192.168.0.35 netmask 255.255.255.0

while getopts a:d:n:e:s:t:p:c: value
do
case $value in
n) node=$(echo "$OPTARG" |tr '[A-Z]' '[a-z]') ;;	
e) event=$(echo "$OPTARG" |tr '[A-Z]' '[a-z]') ;;
s) success=$(echo "$OPTARG") ;;
t) timestamp=$(echo "$OPTARG") ;;
d) detail=$(echo "$OPTARG") ;;
p) sprimary=$(echo "$OPTARG") ;;
*) usage ;;
esac
done


generic_vars


#if [ "$configfile" = "" ]; then
#  configfile="${inst_home}/cfg/repmgrevent.default.cfg"
#fi
#if [ ! -e ${configfile} ] ; then 
#   abort 9 "Error - Unable to locate default config file ${configfile}"
#fi


write_history_log "START:${script_full} for Postgres Database - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started "
write_log "Parameters:"
write_log " $* "
write_log "Number of args $#"

#write_log "Using ${configfile} file for Parms"
#write_log "Read $type Config file ${configfile}"
write_log "Recording event as ${event}"
case $event in
	standby_switchover) 
		;;
	standby_promote) 
		sudo /opt/psql/rootscripts/repmgr_vip.sh -o add -v n -t standby_promote
		sudo /opt/psql/rootscripts/repmgr_vip.sh -o validate -v n -t standby_promote
		;;
	*)
	;;
esac
write_history_log "END:${script_full} for Postgres Database - Finished. "
