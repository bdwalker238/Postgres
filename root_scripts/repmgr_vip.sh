#!/usr/bin/env bash
#set -x
#
# repmgr_vip.sh
# 
# Description :
  
# Used by EDB repmgr  to assign vips to Network Devices
#
# Version : 0.3 

source ./opt/psql/common/common_functions.sh



usage() {
echo "Usage:" 
echo "${script_full} -o add/delete/validate/refresh [-v] n|y {-d device} {-c config file} {-n repmgr node id} {-m netmask} {-ip vip}" 
exit 99
}





validate_netmask () {
    local n_masks=(${1//./ })
    [ "${#n_masks[@]}" -ne 4 ] && return 1
    for i in ${1//./ }; do
        bits=$(echo "obase=2;ibase=10;$i" | bc)
        pre=$((8-${#bits}))
        if [ "$bits" = 0 ]; then
            zeros=00000000
        elif [ "$pre" -gt 0 ]; then
            zeros=$(for ((i=1;i<=$pre;i++)); do echo -n 0; done)
        fi
        b_mask=$b_mask$zeros$bits
            unset zeros
    done
    if [ $b_mask = ${b_mask%%0*}${b_mask##*1} ]; then
        return 0
    else
        return 1
    fi
}

validate_ipaddr() {
 local ldevice=$1
 local lipaddr=$2
 local myreturn=0
 ifconfig ${ldevice}| grep -i ${lipaddr} >/dev/null
 rc=$?
 if [ $rc = 0 ] ; then
   # echo "IP ${primmaryvip} is up."
    myreturn=0
 else
   # echo "IP ${primmaryvip} is down."
    myreturn=1
 fi
 return ${myreturn}
}


add_ipaddr() {
local myreturn=0
local ldevice=$1
local lipaddr=$2
write_log "Adding ${lipaddr} to device ${ldevice}."
ifconfig ${ldevice} inet ${lipaddr} netmask 255.255.255.0
return $myreturn

}

del_ipaddr() {

 local myreturn=0
 local ldevice=$1
 local lipaddr=$2
 write_log "Delete ${lipaddr} from device ${ldevice}."
 ifconfig ${ldevice} del ${lipaddr}
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
i) primaryvip=$(echo "$OPTARG") ;;
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
      device=$(grep -i "^DEVICE" ${configfile} |cut -f2 -d= |tr -d '"' | awk ' { print $1 }')
  else
     abort 14 "Error - You didn't specify a ethernet device in either command arguments or config file! "
  fi
  write_log "Read from config file Network device name $device."
else
  write_log "Using argument value Network device name $device."
fi 
if [ "$primaryvip" = "" ]; then
  grep -i "^PRIMARYVIP" ${configfile} >/dev/null
  rc=$?
  if [ ${rc} = 0 ]; then
     primaryvip=$(grep -i "^PRIMARYVIP" ${configfile} |cut -f2 -d= |tr -d '"' | awk ' { print $1 }')
   else
    abort 15 "Error - You didn't specify a ip address [VIP] in either command arguments or config file!"
   fi
fi
if [[ ! "$primaryvip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
   abort 21 "Error - Invalid argument ${primaryvip} specified!"
fi
write_log "Using ip address $primaryvip."
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
   validate_ipaddr ${device} ${primaryvip}
   returncode=$?
   if [ ${returncode} = 1 ]; then
     add_ipaddr ${device} ${primaryvip}
     returncode=$?
   else
     abort 20 "Unexpected Error - ${primaryvip} is already defined @ ${device} "
   fi
   validate_ipaddr ${device} ${primaryvip}
   returncode=$?
   ;;
DELETE)
   del_ipaddr ${shortdevice} ${primaryvip}
   ;;
REFRESH)
   write_log "Delete $primaryvip from device $device."
   del_ipaddr ${shortdevice} ${primaryvip}
   validate_ipaddr ${device} ${primaryvip}
   returncode=$?
   if [ ${returncode} = 1 ]; then
     write_log "Adding $primaryvip to device $device."
     add_ipaddr ${device} ${primaryvip}
     returncode=$?
   else
     abort 20 "Unexpected Error - ${primaryvip} is already defined @ ${device} "
   fi
   ;;
VALIDATE)
   validate_ipaddr ${device} ${primaryvip}
   returncode=$?
   if [ ${returncode} = 0 ]; then
    echo "Script ${script_full} reports IP ${primaryvip} is up."
   else
    echo "Script ${script_full} reports IP ${primaryvip} is down."
   fi
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
