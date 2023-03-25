#!/usr/bin/env bash
#set -x

source /opt/psql/common/common_functions.sh

usage() {
echo "Usage:" 
echo "${script_full}  "
echo "Valid Arguments:"
echo "-d databasename"
echo "-c Custom Config file"
echo "-t Tag - Used to identify job."
echo "Options in Config file:"
echo "ignore_errors Should script ignore errors (yes/no) Future Use."
echo "max_duration = Max Duration of script in minutes. Future Use."
echo "cutofftime =  Drop dead cut of time of script . Future Use."
echo "include_tabs = Tables to include. include_tabs=table1,table2,table3,etc."
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
exit 99
}

read_config_file() {

  myconfigfile=$1
  if [ -e ${myconfigfile} ] ; then
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
	  #exclude_tabs=$(grep -i "^EXCLUDETAB" ${myconfigfile} | cut -f2 -d= |tr -d '"' | awk ' {print $1} ' |tr [a-z] [A-Z])
          #exclude_schemas=$(grep -i "^EXCLUDESCHEMA" ${myconfigfile} | cut -f2 -d= | tr -d '"' | awk ' {print $1} ' |tr [a-z] [A-Z])
          #reattempt_codes=$(grep -i "^EXCLUDETAB" ${myconfigfile} | cut -f2 -d=| tr -d '"' | awk ' {print $1} '| tr [a-z] [A-Z])
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

   else
     echo "Error - Unable to read config file ${myconfigfile}; Did you set a full path?"
     exit 5
fi
}

ignore_errors="YES"
verbose="Y"
vacuumverbose="yes"
max_duration=120
tab_max_duration=30
exclude_tabs=""
exclude_schemas=""
reattempt_codes=""
tables=""
cut_off=""
hlog_thresh=16
njobs=2
vacuumdbstring=""
skiplocked="N"
parallel_workers=""
vacuumdb_cmd=""
min_mxid_age=-1
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

write_history_log "START:${script_full} for Postgres Database - started. "
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

write_log "Script Completed Successfully"
write_history_log "FINISHED Script Successfully - ${script_full}" 
exit 0