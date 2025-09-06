#!/usr/bin/env bash
#set -x
# 17/2/2024 V1
# 18/2/2024 V1.1
# 30/6/2024 V1.2   Add more TABLE code

usage() {
echo "Usage:" 
echo "${script_full}  "
echo "Valid Arguments:"
echo "-d databasename"
echo "-c Custom Config file"
echo "-t Tag - Used to identify job."
echo "Options in Config file:"
echo "scriptmode=DATABASE/TABLE"
echo "ignore_errors Should script ignore errors (yes/no) Future Use."
echo "max_duration = Max Duration of script in minutes. Future Use."
echo "cutofftime =  Drop dead cut of time of script . Future Use."
echo "include_tabs = Tables to include. include_tabs=table1,table2,table3,etc."
echo "include_schema = Schema to include. include_schema=schema1,schema2,etc"
echo "exclude_tabs = Tables to exclude. Future Use."
echo "exclude_schema = Schemas to exclude. Future Use."
echo "reattempt_codes. List errorcodes to ignore. Possible Future Use"
echo "vacuumdb_cmd = Full path to vacuumdb command."
echo "mode=--analyze/--freeze/--analyze-in-stages.  Optional"
echo "database = Database name to run vacuumdb/vacuum commands. Default is all if not specfied in config file."
echo "njobs = Number of jobs to run. Default is 2 if not specfied in config file."
echo "parallel_workers = Postgres 13+ only. parallel_workers = specify the number of parallel workers for parallel vacuum. Default None"
echo "min_mxid_age = Only execute the vacuum or analyze commands on tables with a transaction ID age of at least xid_age. Postgres 12+"
echo "min_xid_age = Only execute the vacuum or analyze commands on tables with a multixact ID age of at least mxid_age. Postgres 12+"
echo "vacuumverbose=empty"
echo "SKIPLOCKED=Y/N. Optional. Default N"
echo "INDEXBLOAT=Percent without %". Default 40%
exit 99
}

write_log() {
local dt=$(date +%Y-%m-%d-%H-%M.%S)
echo "$dt - ${my_pid}\t-$1" 
}

write_history_log() {
local dt=$(date "+%a %d %b %Y %H:%M:%S")
echo "$dt ${my_pid}\t: $1" 
}

abort() {
   write_log "$2"
   write_log "${script_name} ended abnormally."
   write_history_log "${script_full} for instance ${inst} - ended abbormally."
   echo $2
   exit $1
}


pg_reindex() {

local ii=0
local dbname1="$1"
local ltype="$2"
local lschema="$4"
local lrelation="$5"
local lmode="$6"
local psql_ret1=""
local psql_rc1=0
local lstatement=""

if [ "$ltype" = "table" ]; then 
  lstatement = "REINDEX (VERBOSE) TABLE ${lschema}.${lrelation}"
elif [ "$ltype" = "index" ];
  lstatement = "REINDEX (VERBOSE) INDEX ${lschema}.${lrelation}"
fi

if [ "$lmode" = "online" ]; then 
  lstatement = "${lstatement} CONCURRENTLY"
else
  lstatement = "${lstatement}"
fi
while [ $ii -lt 2 ]; do
 write_log "Performing index reorg command - ${statement}."
 psql_ret1=$(psql -qAtX -d ${dbname1}  --single-transaction -c "${lstatement}" -w )
 psql_rc1=$?
 if [ $psql_rc1 -ne 0 ]; then
   sqlcode=$(echo ${psql_ret1} |awk '{print $1}')
   write_log "Issue encountered whilst performing reindex of table ${lschema}.${ltable}: ${dpsql_ret1}."
   
   case $sqlcode in
   SQL2211N) let err_cnt=$err_cnt+1 ;;
   SQL2213N) let err_cnt=$err_cnt+1 ;;
   SQL2214N) let err_cnt=$err_cnt+1 ;;
   SQL2216N) let err_cnt=$err_cnt+1 ;;
   SQL2217N) let err_cnt=$err_cnt+1 ;;
   SQL2219N) let err_cnt=$err_cnt+1 ;;
   SQL2212N) let wrn_cnt=$wrn_cnt+1 ;;
   SQL2220W) let wrn_cnt=$wrn_cnt+1 ;;
esac
if [ "`echo ${reattempt_codes} |grep -w ${sqlcode}`" = "" ]; then
  ii=2
  break
else 
  write_log "Error code deteched as candidate for re-attempt"
fi
else
  write_log "Reindex of indexes on ${lschema}.${ltable} completed successfully."
  ii=2
fi
let ii=$ii+1
done
db2 connect reset >/dev/null
db2_rc1=$?
 sed -i "/^${ltable}$/d" $curParal
}

vacuum_table_freeze() {
local ii=0
local dbname1="$1"
local lschema="$2"
local ltable="$3"
local psql_ret1=""
local psql_rc1=0
local lstatement=""
lstatement = "VACUUM (FREEZE,VERBOSE,ANALYZE,SKIP_LOCKED) TABLE ${lschema}.${ltable}"

while [ $ii -lt 2 ]; do
 write_log "Performing vacuum table frezze command - ${statement}"
 psql_ret1=$(psql -qAtX -d ${dbname1}  --single-transaction -c "${lstatement}" -w )
 psql_rc1=$?
 if [ $psql_rc1 -ne 0 ]; then
   sqlcode=$(echo ${psql_ret1} |awk '{print $1}')
   write_log "Issue encountered whilst performing reorg of ${ltable}: ${psql_ret1}"
   
   case $sqlcode in
   SQL2211N) let err_cnt=$err_cnt+1 ;;
   SQL2213N) let err_cnt=$err_cnt+1 ;;
   SQL2214N) let err_cnt=$err_cnt+1 ;;
   SQL2216N) let err_cnt=$err_cnt+1 ;;
   SQL2217N) let err_cnt=$err_cnt+1 ;;
   SQL2219N) let err_cnt=$err_cnt+1 ;;
   SQL2212N) let wrn_cnt=$wrn_cnt+1 ;;
   SQL2220W) let wrn_cnt=$wrn_cnt+1 ;;
esac
if [ "`echo ${reattempt_codes} |grep -w ${sqlcode}`" = "" ]; then
  i=2
  break
else 
  write_log "Error code deteched as candidate for re-attempt"
fi
else
  write_log "Reorg of ${ltable} completed successfully."
  i=2
fi
let i=$i+1
done
sed -i "/^${ltable}$/d" $curParal
}

vacuum_table_analyze() {
local ii=0
local dbname1="$1"
local lschema="$2"
local ltable="$3"
local psql_ret1=""
local psql_rc1=0
local lstatement=""
lstatement = "VACUUM (ANALYZE,VERBOSE,SKIP_LOCKED) TABLE ${lschema}.${ltable}"

while [ $ii -lt 2 ]; do
 write_log "Performing vacuum table frezze command - ${statement}"
 psql_ret1=$(psql -qAtX -d ${dbname1}  --single-transaction -c "${lstatement}" -w )
 psql_rc1=$?
 if [ $psql_rc1 -ne 0 ]; then
   sqlcode=$(echo ${psql_ret1} |awk '{print $1}')
   write_log "Issue encountered whilst performing reorg of ${ltable}: ${psql_ret1}"
   
   case $sqlcode in
   SQL2211N) let err_cnt=$err_cnt+1 ;;
   SQL2213N) let err_cnt=$err_cnt+1 ;;
   SQL2214N) let err_cnt=$err_cnt+1 ;;
   SQL2216N) let err_cnt=$err_cnt+1 ;;
   SQL2217N) let err_cnt=$err_cnt+1 ;;
   SQL2219N) let err_cnt=$err_cnt+1 ;;
   SQL2212N) let wrn_cnt=$wrn_cnt+1 ;;
   SQL2220W) let wrn_cnt=$wrn_cnt+1 ;;
esac
if [ "`echo ${reattempt_codes} |grep -w ${sqlcode}`" = "" ]; then
  i=2
  break
else 
  write_log "Error code deteched as candidate for re-attempt"
fi
else
  write_log "Reorg of ${ltable} completed successfully."
  i=2
fi
let i=$i+1
done
sed -i "/^${ltable}$/d" $curParal
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



read_config_file() {

  myconfigfile=$1
  if [ -e ${myconfigfile} ] ; then
      grep -i "^SCRIPTMODE" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
        scriptmode=$(grep -E "^SCRIPTMODE=(DATABASE|TABLE)$" ${config}|cut -f2 -d=|tr '[a-z]' '[A-Z]')
      fi
      echo "scriptmode=DATABASE/TABLE"
	  grep -i "^IGNORERRORS" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
            ignore_errors=$(grep -i "^IGNORERRORS" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk '{print $1}'| tr [a-z] [A-Z])
          fi
	  grep -i "^MAXDURATION" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
	     max_duration=$(grep -i "^MAXDURATION" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
          fi 
	  grep -i "^TABLEMAXDURATION" ${myconfigfile} >/dev/null
	  rc=$?
          if [ $rc -eq 0 ]; then
             TABLEMAXDURATION=$(grep -i "^TABLEMAXDURATION" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
          fi
	  grep -i "^CUTOFFTIME" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
	    cutofftime=$(grep -i "^CUTOFFTIME" ${myconfigfile} | cut -f2 -d= | tr -d '"' | awk ' {print $1} ')
          fi
	  grep -i "^VACUUMDB_CMD" ${myconfigfile} >/dev/null
          rc=$?
	  if [ $rc -eq 0 ]; then
            vacuumdb_cmd=$(grep -i "^VACUUMDB_CMD" ${myconfigfile} | cut -f2 -d=| tr -d '"' | awk ' {print $1} '| tr [A-Z] [a-z])
          fi
	  if [ "$database" = "" ]; then
	  	grep -i "^DATABASE" ${myconfigfile} >/dev/null
	  	rc=$?
	  	if [ $rc -eq 0 ]; then
             		database=$(grep -i "^DATABASE" ${myconfigfile}|  cut -f2 -d= |tr -d '"' | awk ' {print $1} ' |tr [A-Z] [a-z])
			write_log "Read Config file - database = '${database}'."
		else
		   write_log "Using default setting database = 'all'"
                   database="all"
		fi
	  else
               write_log "Setting variable database from command argument value '$database'." 
	  fi 
	  grep -i "^MODE" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
            mode=$(grep -i "^MODE" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} '| tr [A-Z] [a-z])
	  fi 
	  grep -i "^NJOBS" ${myconfigfile} >/dev/null
	  rc=$?
          if [ $rc -eq 0 ]; then
            njobs=$(grep -i "^NJOBS" ${myconfigfile} |  cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
          fi
	  grep -i "^PARALLEL_WORKERS" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
            parallel_workers=$(grep -i "^PARALLEL_WORKERS" ${myconfigfile}| cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
	  fi 
	  grep -i "^MIN_MXID_AGE" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
             min_mxid_age=$(grep -i "^MIN_MXID_AGE" ${myconfigfile}| cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
          fi
	  grep -i "^MIN_XID_AGE" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
	    min_xid_age=$(grep -i "^MIN_XID_AGE" ${myconfigfile} |  cut -f2 -d= |tr -d '"' | awk ' {print $1} ')
          fi
	  grep -i "^VACUUMVERBOSE" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
	     vacuumverbose=$(grep -i "^VACUUMVERBOSE" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} '| tr [A-Z] [a-z])
	  fi
	  grep -i "^SKIPLOCKED" ${myconfigfile} >/dev/null
	  rc=$?
          if [ $rc -eq 0 ]; then	  
       	   skiplocked=$(grep -i "^SKIPLOCKED" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} '| tr [a-z] [A-Z])
          fi
	  grep -i "^INCLUDE_TABS" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
		  tables=$(grep -i "^INCLUDE_TABS" ${myconfigfile}|cut -f2 -d= | tr -d '"' |awk ' {print $1 }')
		  tables=$(echo ${tables}|tr ',' ' ')
      fi
	  exclude_tabs=$(grep -i "^EXCLUDETAB" ${CONFIG} | cut -f2 -d= |tr -d '"' | awk ' { print $1 } ' |tr [a-z] [A-Z])
	  exclude_schemas=$(grep -i "^EXCLUDESCHEMA" ${CONFIG} | cut -f2 -d= |tr -d '"' | awk ' { print $1 } ' |tr [a-z] [A-Z])
	  include_schemas=$(grep -i "^INCLUDESCHEMA" ${CONFIG} | cut -f2 -d= |tr -d '"' | awk ' { print $1} ' |tr [a-z] [A-Z])
	  grep -i "^INDEXBLOAT" ${myconfigfile} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
	      indexbloat_per=$(grep -i "^INDEXBLOAT" ${CONFIG} | cut -f2 -d= |tr -d '"' | awk ' { print $1} ')
	  fi
   else
     echo "Error - Unable to read config file ${myconfigfile}; Did you set a full path?"
     exit 5
fi
}

vacuumdb_function() {

if [ "${vacuumverbose}" = "empty" ] ; then
	vacuumverbose=""
elif [ "${vacuumverbose}" = "yes" ]; then
	vacuumverbose="--verbose"
else
	abort 50 "Error The value of variable verbose = $verbose is incorrect!"
fi

if [ "${skiplocked}" = "N" ]; then
	skiplocked=""
elif ["${skiplocked}" = "Y" ]; then 
	skiplocked="--skip-locked"
else
	abort 51 "Error The value of variable skiplocked = $skiplocked is incorrect!"
fi

if [ $min_mxid_age -eq -1 ]; then
	min_mxid_age=""
else
	tmpmin=$min_mxid_age
	min_mxid_age="--min-mxid-age ${tmpmin}"
fi

if [ $min_xid_age -eq -1 ]; then
        min_xid_age=""
else
        tmpmin=$min_xid_age
        min_xid_age="--min-xid-age ${tmpmin}"
fi

if [ $njobs -gt 1 ] ; then
        njobs="-j=2"
else
       njobs=""
       # tmpjobs=$njobs
       # njobs="-j=${tmpjobs}"
fi

if [ "${database}" = "all" ]; then
	database="--all"
else
   tmpdb=$database
   database="--dbname=$tmpdb"
fi
vacuumdbstring="vacuumdb ${mode} ${njobs} ${min_mxid_age} ${min_xid_age} ${skiplocked} ${vacuumverbose} ${echo} ${password} ${database}"
vacuumdbstring=$(echo ${vacuumdbstring} |sed 's/     / /g'|sed 's/    / /g'|sed 's/   / /g'|sed 's/  / /g')

#echo "DEBUG $vacuumdbstring" 
touch ${scriptout}
write_log "Issuing Linux command: ${vacuumdbstring}."

${vacuumdbstring} >${scriptout} 2>&1 &
vacuumpid=$!
doiexist=$(ps ax | grep -w $vacuumpid | grep -v grep)
i=0; j=0 ; l=0
while [ "${doiexist}" != "" ] ; do 
     k=$(cat ${scriptout} | wc -l |bc)
     l=$(echo "$k-$j" | bc )      
	 tail -${l} "${scriptout}" |while read log_line ; do
     if [ "${log_line}" != "" ] ; then
       write_log "VDB> ${log_line}"
     fi
     done
	 j=$(echo "$j+$l" | bc )
     i=$(echo "$i+1" | bc) 
  sleep 5
  doiexist=$(ps ax | grep -w $vacuumpid | grep -v grep)
done
if wait $vacuumpid; then
	k=$(cat ${scriptout} | wc -l | bc)
	l=$(echo "$k-$j" | bc )  
	tail -${l} "${scriptout}" |while read log_line ; do
	if [ "${log_line}" != "" ] ; then
       write_log "VDB> ${log_line}"
    fi
	done
    write_log ""
    write_log "Command '${vacuumdbstring}' completed successfully."
    rm -f ${scriptout}
else
   rc=$?
   k=$(cat ${scriptout} | wc -l |bc)
   l=$(echo "$k-$j" | bc )
   tail -${l} "${scriptout}" |while read log_line ; do
	if [ "${log_line}" != "" ] ; then
       write_log "VDB> ${log_line}"
    fi
	done
	rm -f ${scriptout}
	abort ${rc} "Error - with command 'vacuumdbstring'."
fi	

}

scriptmode="DATABASE"
ignore_errors="YES"
verbose="Y"
vacuumverbose="yes"
max_duration=120
tab_max_duration=30
exclude_tabs=""
exclude_schemas=""
reattempt_codes=""
historylog=""
log_main=""
tables=""
cut_off=""
hlog_thresh=16
njobs=2
vacuumdbstring=""
skiplocked="N"
parallel_workers=""
vacuumdb_cmd=""
min_mxid_age=-1
indexbloat_per=40
min_xid_age=-1
database=""
echo="-e"
mode="-F"
password="-w"
locked=""
myhost=$(hostname -s)
returncode=0
tag="Has not been provided in command line arguments"
type1="custom"
configfile=""
listindexsql="SELECT schemaname, indexname FROM pg_indexes where schemaname <> 'pg_catalog' ORDER BY indexname;"

exec 3>&1 4>&2
trap "jobs -p | xargs kill 2>/dev/null; exec 2>&4 1>&3" EXIT

which_os

while getopts c:d:t: value
do 
case $value in
t) tag=$(echo "$OPTARG" |tr '[a-z]' '[A-Z]') ;;
c) configfile=$(echo "$OPTARG") ;;
d) database=$(echo "$OPTARG") ;;
*) usage ;;
esac
done  

generic_vars

if [ "$configfile" = "" ]; then
  type1="default"
  configfile="${inst_home}/cfg/psql_default_vacuumdb.cfg"
fi

if [ ! -e ${configfile} ] ; then 
   abort 9 "Error - Unable to locate config file ${configfile}."
fi

scripttmp="${dba_tmp_dir}/output.XXXX"
scriptout="$(mktemp ${scripttmp})" || { echo "Error - Failed to create temp file $scripttmp"; exit 1; }

exec 1>>${historylog} 2>&1 
write_history_log "START:${script_full} for Postgres Database - started. "
touch ${log_main} && truncate -s 0 ${log_main}
exec 1>>${log_main} 2>&1
write_log "-------------------------------------------------------------------"
write_log "${script_name} started on hostname ${myhost}."
write_log "Parameters:"
write_log " $* "
write_log "Script called with tag(it) argument : ${tag}."
write_log "Read ${type1} Config file ${configfile} for configuration variables."

read_config_file $configfile
write_log "Finish reading Config file."

write_log "Checking if database name is valid - "

if [ "${database}" = "all" ]; then
  write_log "Skipping database name check, as value is set to 'all'"
  scriptmode="DATABASE"
else
  psql -qAtX -c "copy (SELECT datname FROM pg_database) to stdout" >/dev/null
  rc=$?
  if [ $rc -eq 0 ]; then
	  psql -qAtX -c "copy (SELECT datname FROM pg_database) to stdout"|grep ${database} >/dev/null
	  rc=$?
	  if [ $rc -eq 0 ]; then
		  write_log "Database name '${database}' is a valid name."
	  else
	          abort $rc "Error - Unable to find database '${database}'. Check database name is valid!"
	  fi
   else
	 abort $rc "Error - Unable to connect to Postgres."
 fi
fi

if [ "${scriptmode}" = "DATABASE" ]; then
   vacuumdb_function
else
  vacuum_table_freeze "$dbname" "$schema" "$table" 
  pg_reindex  "$dbname" "table/index" "$schema" "$table/$index" "online/offline"
  echo "placeholder"
fi

log_thresh_min=$(expr $hlog_thresh \* 24)
log_thresh_min=$(expr $log_thresh_min \* 60)
tmplist=$(find ${dba_log_dir}/${script_name}* -type f --mmin +${log_thresh_min})
if [ "${tmplist}" != "" ]; then
  write_log "There are no left over log files in ${dba_log_dir} from previous scripts runs to delete."
else
  for tempfile1 in ${tmplist}; do
  write_log "Identified file ${tempfile1} as being more than $hlog_thresh days old. Deleting."
  rm -f ${tempfile1}
  done
fi  



write_log "Script Completed Successfully."
exec 1>>${historylog} 2>&1 
write_history_log "FINISHED Script Successfully - ${script_full}." 
exit 0
