#!/bin/bash
#set -x

source /opt/psql/common/common_functions.sh 

usage() {

exit 99
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

which_os 

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
