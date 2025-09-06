#!/bin/bash
#
# Script to generate a SAS token for Azure Storage and update PGBackRest configuration,
# then run a backup using PGBackRest.
# Requires Azure CLI and PGBackRest to be installed.
# Usage: postgres_backup.sh -c config_file
# The config file should contain the following variables:
# SPAPPID - Service Principal Application ID
# SPTENANT - Service Principal Tenant ID
# SPSEC - Service Principal Secret
# STORAGE_ACCOUNT_NAME - Azure Storage Account Name
# CONTAINER_NAME - Azure Storage Container Name
# PG_BACKREST_CONF - Path to the PGBackRest configuration file
# EXPIRY_HOURS - Expiry time for the SAS token in hours
# AZURERESOURCEGROUP - Azure Resource Group Name
# STANZA - PGBackRest Stanza Name
#  The Service Principal must have sufficient permissions to access the storage account and generate SAS tokens.
    # Storage Account Key Operator Service Role
    # Storage Blob Data Contributor Role


usage() {

echo  "Usage $0 -c config file"
echo  "config file -  stores the variables required for the script to run"
echo  "SPAPPID - Service Principal Application ID"
echo  "SPTENANT - Service Principal Tenant ID"
echo  "SPSEC - Service Principal Secret"
echo  "STORAGE_ACCOUNT_NAME - Azure Storage Account Name"
echo  "CONTAINER_NAME - Azure Storage Container Name"
echo  "PG_BACKREST_CONF - Path to the PGBackRest configuration file"
echo  "EXPIRY_HOURS - Expiry time for the SAS token in hours"
echo "AZURERESOURCEGROUP - Azure Resource Group Name"
echo  "STANZA - PGBackRest Stanza Name"	
echo  "Example: $0 -c ~/cfg/postgres_backup.cfg."
echo  "This script generates a SAS token for Azure Storage and updates the PGBackRest configuration file with the generated toke, and runs a backup."
echo  "It requires Azure CLI to be installed and configured with the necessary permissions."
echo  "Ensure that the Azure CLI is logged in with sufficient permissions to access the storage account and generate SAS tokens."
echo  "The script will log its actions to the log file located at ${dba_log_dir}/${log_main_name}."
echo  "The script will also write a history log to ${dba_log_dir}/db2_history.log."
echo  "The script will exit with status 0 on success, or a non-zero status on failure."
echo  "The script is designed to be run manually and ideally automated with the necessary permissions to access the Azure"
echo  "Additional further default options can be specified in the configuration file, located at ~/cfg/postgres_backup.cfg"
exit 99
}

write_log() {
	dt=$(date +%Y-%m-%d-%H-%M.%S)
	$echoe "$dt - ${my_pid}\t-$1" >> ${log_main}
	$echoe "$dt - ${my_pid}\t-$1"
}

write_history_log() {
	dt=$(date "+%a %d %b %Y %H:%M:%S")
	$echoe "$dt ${my_pid}\t: $1" >>${dba_log_dir}/psql_history.log
}


generic_vars() {
	my_pid=$$
	script_name=$(basename ${0%.*})
	script_full=$(basename $0)
	script_date=$(date +%Y%m%d)
	inst_home_dir=$(echo ~)
	dba_dir="/psql/dba"
	dba_log_dir=${dba_dir}/logs
	log_main_name=${script_name}.${script_date}.log
	log_main=${dba_log_dir}/${log_main_name}
}


 
echoe="echo -e"
generic_vars
storage_account_name=""
container_name=""
pg_backrest_conf=""
expiry_hours=""
spappid=""
sptenant=""
spsec=""
stanza=""
azureresourcegroup=""
expirydate=$(date -u -d "+24 hours" +"%Y-%m-%dT%H:%M:%SZ")


configfile="${inst_home_dir}/cfg/postgres_backup.cfg"

write_history_log "${script_full} for database ${DBNAME} - started. "
write_log "-------------------------------------------------------------------"
write_log "${script_name} started "
write_log "Parameters:"
write_log " $* "
write_log "Using ${CONFIG} file for Variables"

##STORAGE_ACCOUNT_NAME="storage-account"
##CONTAINER_NAME="container-name"
##PG_BACKREST_CONF="/etc/pgbackrest.conf"
#expirydate=$(date -u -d "+12 hours" +"%Y-%m-%dT%H:%M:%SZ")

if [[ -e $configfile ]] ; then
   chmod 600 $configfile
   grep "^AZURERESOURCEGROUP" $configfile >/dev/null
   rc=$?
   if [[ $rc -eq 0 ]]; then
	azureresourcegroup=$(cat $configfile |grep -i "^AZURERESOURCEGROUP" |cut -f2 -d= |tr -d '"' | awk '{print $1}') 
   else
	write_log "Error - Unable to locate AZURERESOURCEGROUP variable in $configfile."
	usage
   fi
   grep "^SPAPPID" $configfile >/dev/null
   rc=$?
   if [[ $rc -eq 0 ]]; then
	spappid=$(cat $configfile |grep -i "^SPAPPID" |cut -f2 -d= |tr -d '"' | awk ' { print $1 } ' ) 
   else
	write_log "Error - Unable to locate SPAPPID varibale in $configfile."
        usage
   fi

   grep "^SPTENANT" $configfile >/dev/null
   rc=$?
   if [[ $rc -eq 0 ]]; then
      sptenant=$(cat $configfile |grep -i "^SPTENANT" |cut -f2 -d= |tr -d '"' | awk '{print $1}') 
   else
      write_log "Error - Unable to locate SPTENANT varibale in $configfile."
      usage
   fi

   grep "^SPSEC" $configfile >/dev/null
   rc=$?
   if [[ $rc -eq 0 ]]; then
      spsec=$(cat $configfile |grep -i "^SPSEC" |cut -f2 -d= |tr -d '"' | awk '{print $1}') 
   else
      write_log "Error - Unable to locate SPSEC varibale in $configfile."
      usage
    fi
    grep "^STORAGE_ACCOUNT_NAME" $configfile >/dev/null
    rc=$?
    if [[ $rc -eq 0 ]]; then
	storage_account_name=$(cat $configfile |grep -i "^STORAGE_ACCOUNT_NAME" |cut -f2 -d= |tr -d '"' | awk '{print $1}') 
    else
	write_log "Error - Unable to locate STORAGE_ACCOUNT_NAME in $configfile."
	usage
    fi
    grep "^CONTAINER_NAME" $configfile >/dev/null
    rc=$?
    if [[ $rc -ne 0 ]]; then
	write_log "Error - Unable to locate CONTAINER_NAME in $configfile."
	usage
    else	
	container_name=$(cat $configfile |grep -i "^CONTAINER_NAME" |cut -f2 -d= |tr -d '"' | awk '{print $1}')
    fi
    grep "^STANZA" $configfile >/dev/null
    rc=$?
    if [[ $rc -ne 0 ]]; then
   	write_log "Error - Unable to locate PGBACKREST STANZA in $configfile."
	usage
    fi
    stanza=$(cat $configfile |grep -i "^STANZA" |cut -f2 -d= |tr -d '"' | awk '{print $1}')
    grep "^PG_BACKREST_CONF" $configfile >/dev/null
    rc=$?
    if [[ $rc -ne 0 ]]; then
	write_log "Error - Unable to locate PG_BACKREST_CONF in $configfile."
	usage
    fi
    pg_backrest_conf=$(cat $configfile |grep -i "^PG_BACKREST_CONF" |cut -f2 -d= |tr -d '"' | awk '{print $1}')
    if [[ ! -f $pg_backrest_conf ]]; then
      write_log "Error - PG_BACKREST_CONF file does not exist: $pg_backrest_conf"
      usage
    fi
    write_log "Completed reading configuration file: $configfile"
else
    write_log "Error - Configuration file $configfile does not exist."
    usage
fi
write_log "Using Azure Resource Group: $azureresourcegroup."
write_log "Using Storage Account Name: $storage_account_name."
write_log "Using Container Name: $container_name."
write_log "Using PGBackRest Configuration File: $pg_backrest_conf."
write_log "using PGBackRest Stanza: $stanza."
write_log "Using Expiry Date for SAS Token: $expirydate."

write_log "Using Service Principal Application ID: $spappid."
write_log "Using Service Principal Tenant ID: $sptenant."

write_log "Attempting to login to Azure with Service Principal credentials."
write_log "az login --service-principal --username \"$spappid\" --tenant \"$sptenant\""
exit 1

az login --service-principal --username "$spappid" --tenant "$sptenant" --password "$spsec" > /dev/null 2>&1
rc=$?

if [ $rc -ne 0 ]; then	
   write_log "Error - Azure login failed with Service Principal credentials."
   exit 1
else
   write_log "Azure login successful."
   write_log "Recording"
   az account list
fi

write_log "Retrieve the Storage Account Key"
# Retrieve the Storage Account Key
account_key=$(az storage account keys list \
    --resource-group "$azureresourcegroup" \
    --account-name "$storage_account_name" \
    --query "[0].value" \
    --output tsv)
 
if [ -z "$account_key" ]; then
    echo "Failed to retrieve storage account key."
    exit 1
fi
write_log "Retrieve the Storage Account Key Successfully."
write_log "About to generate SAS Token" 
# Generate SAS Token
sas_token=$(az storage container generate-sas \
    --account-name "$storage_account_name" \
    --name "$container_name" \
    --permissions acdlrw \
    --expiry "$expirydate" \
    --https-only \
    --account-key "$account_key" \
    --output tsv)
 
if [ -z "$sas_token" ]; then
    echo "Failed to generate SAS token."
    exit 1
fi
 
echo "SAS Token generated successfully. It will expire at $expirydate."
 
# Update PGBackRest configuration with the SAS token
echo "Updating PGBackRest configuration on backup server..."
 
awk -v sas_token="$sas_token" '/^repo1-azure-key=/ {$0="repo1-azure-key=" sas_token} {print}' "$pg_backrest_conf" > /tmp/pgbackrest.conf.tmp && mv /tmp/pgbackrest.conf.tmp "$pg_backrest_conf"
if [ $? -eq 0 ]; then
    echo "PGBackRest configuration updated successfully."
else
    echo "Failed to update PGBackRest configuration."
    exit 1
fi
 
echo "SAS token update completed."
echo "Running PGBackRest backup..."
pgbackrest --stanza=$stanza --log-level-console=info backup
rc=$?
if [ $rc -ne 0 ]; then	
	write_log "Error - PGBackRest backup failed with exit code $rc."
	exit $rc
else
	write_log "PGBackRest backup completed successfully."
fi
write_log "Backup completed successfully."
write_log "Issue az logout."
az logout
write_log "Logout of azure Entra."
write_log "${script_name} completed successfully"
write_history_log "${script_full} for cluster name ${NAME} - ended successfully."
exit 0
