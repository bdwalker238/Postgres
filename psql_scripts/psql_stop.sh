#!/usr/bin/env bash
#set -x

source . /opt/psql/common/common_functions.sh

usage() {
echo "Usage:" 
echo "${script_full}  "
exit 99
}


myhost=$(hostname -s)
returncode=0
label=""
type1="custom"

while getopts l:c: value
do 
case $value in
l) label=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
c) configfile=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;

*) usage ;;
esac
done  

generic_vars

if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/vipmanager.default.cfg"
fi
if [ ! -e ${configfile} ] ; then 
   abort 9 "Error - Unable to locate default config file ${configfile}"
fi

write_history_log "START:${script_full} for Postgres Database - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started on hostname ${myhost}"
write_log "Parameters:"
write_log " $* "
write_log "Called from argument with label(-l) ${label} ."
write_log "Read ${type1} Config file ${configfile} for configuration variables."
sudo /opt/psql/root_scripts/repmgr_vip.sh -o delete
sudo systemctl stop postgresql-11
returncode=$?
if [ $returncode = 0 ]; then
  write_log "${script_name} completed successfully."
  write_history_log "FINISHED:${script_full}  - ended successfully."
else
  write_log "${script_name} completed unsuccessfully."
  write_history_log "FINISHED:${script_full}  - ended unsuccessfully."
fi


return $returncode