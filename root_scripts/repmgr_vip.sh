#!/bin/bash
#set -x
#
# repmgr_vip.sh
# 
# Description :
  
# Used by EDB repmgr  to assign vips to Network Devices
#
# Version : 0.1 

usage() {

exit 99
}


write_log() {
dt=$(date +%Y-%m-%d-%H-%M.%S)
$echoe "$dt - ${my_pid}\t-$1" >> ${log_main}
if [ $verbose = 'Y' ];  then
  $echoe "$dt - ${my_pid}\t-$1"
fi
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
dba_tmp_dir=${dba_dir}/tmp

if  [ ! -e  $dba_log_dir ]; then
  echo "Error - Script Abort - No log directory $dba_log_dir present "
  exit 2
fi

if  [ ! -e  $dba_tmp_dir ]; then
  echo "Error - Script Abort - No tmp directory $dba_tmp_dir present! "
  exit 2
fi

log_main_name=${script_name}.${script_date}.log
log_main=${dba_log_dir}/${log_main_name}
history_log=${dba_log_dir}/postgres_history.log
touch $log_main
touch $history_log
chown postgres:postgres $log_main
chown postgres:postgres $history_log
#DBNAME=`echo ${DBNAME} |tr '[a-z]' '[A-Z]'`
}

validate_ipaddr() {
 local ldevice=$1
 local lipaddr=$2
 local myreturn=0
 ifconfig ${ldevice}| grep -i ${lipaddr} >/dev/null
 rc=$?
 if [ $rc = 0 ] ; then
    echo "IP ${primmaryvip} is up."
    myreturn=0
 else
    echo "IP ${primmaryvip} is down."
    myreturn=1
 fi
 return ${myreturn}
}


add_ipaddr() {
local myreturn=0
return $myreturn

}

del_ipaddr() {

 local myreturn=0
return $myreturn

}

configfile=""
operation=""
type1="custom"
primaryvip=""
netmask=""
device=""
verbose="Y"
returncode=0
node="None Specified"

case $(uname) in 
Linux ) echoe="echo -e"	;;
AIX)	echoe="echo" ;;
*)	echoe="" ;;
esac

# ifconfig ens3:0 inet 192.168.0.35 netmask 255.255.255.0

while getopts o:d:c:i:n:m:v: value
do 
case $value in
c) configfile=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
d) device=$(echo "$OPTARG" |tr '[A-Z]' '[a-z]') ;;
o) operation=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
i) primmaryvip=$(echo "$OPTARG") ;;
m) netmask=$(echo "$OPTARG") ;;
n) node=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
v) verbose=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
*) usage ;;
esac
done  

case $verbose in
    Y|N)  # Ok
    ;;
    *)
        # The wrong first argument.
        echo 'Error Abort - Expected y/n for Verbose' >&2
        exit 1
    ;;
esac



generic_vars


if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/vipmanager.default.cfg"
fi
if [ ! -e ${configfile} ] ; then 
   abort 9 "Error - Unable to locate default config file ${configfile}"
fi

if [ "$operation" = "" ]; then
   abort 19 "Error - You must specify a valid operation - add/delete/refresh!"
fi

write_history_log "START:${script_full} for Postgres Database - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started "
write_log "Parameters:"
write_log " $* "
write_log "Read ${type1} Config file ${configfile} for configuration variables."

if [ "$device" = "" ]; then
  grep -i "^DEVICE" ${configfile} >/dev/null
  rc=$?
  if [ $rc = 0 ]; then
      device=$(grep -i "^DEVICE" ${configfile}  |cut -f2 -d= |tr -d '"' | awk ' { print $1 }')
  else
     abort 14 "Error - You didn't specify a ethernet device in either command arguments or config file! "
  fi
  write_log "Read from config file Network device name $device."
else
  write_log "Using argument value Network device name $device."
fi 
if [ "$primmaryvip" = "" ]; then
  grep -i "^PRIMARYVIP" ${configfile} >/dev/null
  rc=$?
  if [ $rc = 0 ]; then
     primmaryvip=$(grep -i "^PRIMARYVIP"  ${configfile} |cut -f2 -d= |tr -d '"' | awk ' { print $1 }')
   else
    abort 15 "Error - You didn't specify a ip address [VIP] in either command arguments or config file!"
   fi
fi
write_log "Using ip address $primmaryvip."
if [ "$netmask" = "" ]; then
  grep -i "^NETMASK" ${configfile} >/dev/null
  rc=$?
if [ $rc = 0 ]; then
  netmask=$(grep -i "^NETMASK" ${configfile} |cut -f2 -d= |tr -d '"' | awk ' { print $1 }')
else
  abort 16 "Error - You didn't specify a net mask in either command arguments or config file!"
fi
fi
write_log "Using netmask $netmask."


write_log "Record state of network device $device to log file ${log_main}."

shortdevice=$(echo "${device}" |sed s/:[0-9]//g)
ifconfigout=$(ifconfig $shortdevice)
echo ${ifconfigout} >>${log_main}



write_log "Operation $operation specified. "


case $operation in

ADD)  
   write_log "Adding $primmaryvip to device $device."
   ifconfig ${device} inet ${primmaryvip} netmask 255.255.255.0 
   ;;
DELETE)
   write_log "Delete $primmaryvip from device $device."
   ifconfig ${shortdevice} del ${primmaryvip}
   ;;
REFRESH)
   write_log "Delete $primmaryvip from device $device."
   ifconfig ${shortdevice} del ${primmaryvip} 
   write_log "Adding $primmaryvip to device $device."
   ifconfig ${device} inet ${primmaryvip}  netmask 255.255.255.0 
   ;;
VALIDATE)
   validate_ipaddr ${device} ${primmaryvip}
   returncode=$?
   ;;
*) abort 12 "Error - Invalid operation $operation specified!" 
   ;;
esac

write_log "Record state of network device $device to log file ${log_main}."

ifconfigout=$(ifconfig $shortdevice)
echo $ifconfigout >>${log_main}

write_log "${script_name} completed successfully."
write_history_log "FINISHED:${script_full}  - ended successfully."
exit $returncode
