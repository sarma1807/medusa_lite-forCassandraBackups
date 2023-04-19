#############
#!/bin/bash

# medusa_lite list_backups : v01_20230419 : Sarma Pydipally

source ~/.bash_profile > /dev/null

SCRIPT_FOLDER=$(realpath "$(dirname "${BASH_SOURCE[0]}")")


##################################################
### initial configuration
##################################################

# load config parameters
CONFIG_FILE=${SCRIPT_FOLDER}/medusa_lite_config_parameters.sh
source ${CONFIG_FILE} > /dev/null

if [[ "${NUMBER_OF_BACKUPS_TO_KEEP}" -le "2" ]]; then
  echo -e "WARNING : YOU HAVE CONFIGURED VERY LOW VALUE FOR [NUMBER_OF_BACKUPS_TO_KEEP]. YOU MIGHT END UP WITH ZERO BACKUPS."
fi

if [[ "${NUMBER_OF_BACKUPS_TO_KEEP}" -gt "15" ]]; then
  echo -e "WARNING : YOU HAVE CONFIGURED VERY HIGH VALUE FOR [NUMBER_OF_BACKUPS_TO_KEEP]. YOU MIGHT END UP WITH FILESYSTEM FREESPACE ISSUES."
fi

##################################################
### prerequisite checks
##################################################

### identify if Cassandra is UP or DOWN
CASS_PROCESS_COUNT=`ps -ef | egrep -i "CassandraDaemon|dse.server" | grep -v "grep" | wc -l`
if [[ "${CASS_PROCESS_COUNT}" -gt "0" ]]; then
  ### Cassandra is UP

  # get cassandra cluster name
  CASS_CLUSTER_NAME=(`nodetool describecluster | grep -i Name | cut -d":" -f2`)
  
  # get cassandra version
  TMP_CASS_VER=`nodetool version | head -1`
  CASS_VERSION=${TMP_CASS_VER/ReleaseVersion/Apache Cassandra version}
  CASS_VERSION=${CASS_VERSION/DSE/DataStax Enterprise}
  CASS_VERSION=${CASS_VERSION/version:/version :}
  CASS_VERSION=${CASS_VERSION/Apache Cassandra version :/Apache Cassandra version    :}
else
  ### Cassandra is DOWN
  echo "`date +'%d-%b-%Y %I:%M:%S %p'` : Cassandra was DOWN on this node. Script failed with ERRORs." >> ${LOGFILE}
  exit 1
fi


# setup required variables
CURRENT_HOST=`hostname`
CURRENT_HOST_SHORT=`hostname -s`
BACKUPS_FOLDER=${CASS_BACKUP_FOLDER}/${CASS_CLUSTER_NAME}/${CURRENT_HOST_SHORT}


##################################################
### start process
##################################################

# count number of available backups
NUMBER_OF_AVAILABLE_BACKUPS=`ls -l ${BACKUPS_FOLDER} | grep ${CASS_BACKUP_PREFIX} | grep ^d | wc -l`

if [[ "${NUMBER_OF_AVAILABLE_BACKUPS}" -ge "${NUMBER_OF_BACKUPS_TO_KEEP}" ]]; then
  NUMBER_OF_EXPIRED_BACKUPS=$((${NUMBER_OF_AVAILABLE_BACKUPS} - ${NUMBER_OF_BACKUPS_TO_KEEP}))
else
  NUMBER_OF_EXPIRED_BACKUPS=0
fi

if [[ "${NUMBER_OF_EXPIRED_BACKUPS}" -ge "${NUMBER_OF_AVAILABLE_BACKUPS}" ]]; then
  NUMBER_OF_NON_EXPIRED_BACKUPS=$((${NUMBER_OF_AVAILABLE_BACKUPS} - ${NUMBER_OF_EXPIRED_BACKUPS}))
else
  NUMBER_OF_NON_EXPIRED_BACKUPS=0
fi


# identify backups
EXPIRED_BACKUP_TAGS=`ls -l ${BACKUPS_FOLDER} | grep ${CASS_BACKUP_PREFIX} | grep ^d | rev | cut -d" " -f1 | rev | sort | head -${NUMBER_OF_EXPIRED_BACKUPS} | xargs`
NON_EXPIRED_BACKUP_TAGS=`ls -l ${BACKUPS_FOLDER} | grep ${CASS_BACKUP_PREFIX} | grep ^d | rev | cut -d" " -f1 | rev | sort | tail -${NUMBER_OF_BACKUPS_TO_KEEP} | xargs`


# display report
# echo -e `printf "%0.s-" {1..50}`
date +'%d-%b-%Y %I:%M:%S %p'
echo -e "cassandra cluster name      : ${CASS_CLUSTER_NAME}"
echo -e "${CASS_VERSION}"
echo -e " "
echo -e "medusa_lite - list of existing backups for node - ${CURRENT_HOST}"
echo -e `printf "%0.s-" {1..127}`
printf '| %-30s | %-20s | %-14s | %-35s | %-12s | \n' "BACKUP_SNAPSHOT_TAG" "BACKUP_DATE_TIME" "BACKUP_STATUS" "BACKUP_DETAILS" "BACKUP_SIZE" ;
echo -e `printf "%0.s-" {1..127}`


# report expired backups
for eb in ${EXPIRED_BACKUP_TAGS}
do
  # expired backups
  CURRENT_FOLDER=${BACKUPS_FOLDER}/${eb}
  CURRENT_FOLDER_DATETIME=`ls -l --full-time ${BACKUPS_FOLDER} | grep ^d | grep ${eb} | rev | cut -d" " -f3-4 | rev | awk -F"." '{ print $1 }'`
  CURRENT_FOLDER_DETAIL=`tree ${CURRENT_FOLDER} | tail -1`
  CURRENT_FOLDER_SIZE=`du -hx --max-depth=0 ${CURRENT_FOLDER} | cut -f1`
  
  printf '| %-30s | %-20s | %-14s | %-35s | %-12s | \n' "${eb}" "${CURRENT_FOLDER_DATETIME}" "EXPIRED" "${CURRENT_FOLDER_DETAIL}" "${CURRENT_FOLDER_SIZE}" ;
done

if [[ "${NUMBER_OF_EXPIRED_BACKUPS}" -le "0" ]]; then
  printf '| %-123s | \n' "EXPIRED BACKUPS NOT FOUND." ;
fi  

echo -e `printf "%0.s-" {1..127}`

# report non-expired backups
for neb in ${NON_EXPIRED_BACKUP_TAGS}
do
  # expired backups
  CURRENT_FOLDER=${BACKUPS_FOLDER}/${neb}
  CURRENT_FOLDER_DATETIME=`ls -l --full-time ${BACKUPS_FOLDER} | grep ^d | grep ${neb} | rev | cut -d" " -f3-4 | rev | awk -F"." '{ print $1 }'`
  CURRENT_FOLDER_DETAIL=`tree ${CURRENT_FOLDER} | tail -1`
  CURRENT_FOLDER_SIZE=`du -hx --max-depth=0 ${CURRENT_FOLDER} | cut -f1`
  
  printf '| %-30s | %-20s | %-14s | %-35s | %-12s | \n' "${neb}" "${CURRENT_FOLDER_DATETIME}" "AVAILABLE" "${CURRENT_FOLDER_DETAIL}" "${CURRENT_FOLDER_SIZE}" ;
done

if [[ "${NUMBER_OF_NON_EXPIRED_BACKUPS}" -lt "0" ]]; then
  printf '| %-123s | \n' "ZERO BACKUPS AVAILABLE." ;
fi  

echo -e `printf "%0.s-" {1..127}`


##################################################
### final steps
##################################################

#############

