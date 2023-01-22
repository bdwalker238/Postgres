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
tag="Has not been provided in command line arguments."
type1="custom"
configfile=""
verbose="N"

which_os

while getopts c:t: value
do 
case $value in
t) tag=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
c) configfile=$(echo "$OPTARG") ;;
*) usage ;;
esac
done  

generic_vars

if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/psql_stopstart.cfg"
fi

if [ ! -e ${configfile} ] ; then 
   abort 9 "Error - Unable to locate config file ${configfile}."
fi

write_history_log "START:${script_full} for Postgres Database - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started on hostname ${myhost}"
write_log "Parameters:"
write_log " $* "
write_log "Script called with tag(it) argument : ${tag} ."
write_log "Read ${type1} Config file ${configfile} for configuration variables."
write_log " "
write_log "Issue command 'sudo /opt/psql/rootscripts/repmgr_vip.sh -o delete -v n -t "${tag}"' "
sudo /opt/psql/rootscripts/repmgr_vip.sh -o delete -v n -t "${tag}"
sudo systemctl stop postgresql-11
returncode=$?
if [ $returncode = 0 ]; then
  write_log "${script_name} completed successfully."
  write_history_log "FINISHED:${script_full}  - ended successfully."
else
  write_log "${script_name} completed unsuccessfully."
  write_history_log "FINISHED:${script_full}  - ended unsuccessfully."
fi

exit $returncode
