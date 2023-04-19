#############
#!/bin/bash

# medusa_lite purge_backups : v01_20230419 : Sarma Pydipally

source ~/.bash_profile > /dev/null

SCRIPT_FOLDER=$(realpath "$(dirname "${BASH_SOURCE[0]}")")


##################################################
### initial configuration
##################################################

# load config parameters
CONFIG_FILE=${SCRIPT_FOLDER}/medusa_lite_config_parameters.sh
source ${CONFIG_FILE} > /dev/null


# setup required variables
CURRENT_DATETIME_DISPLAY=`date +'%d-%b-%Y %I:%M:%S %p'`
CURRENT_DATETIME=`date +'%Y%m%d-%H%M%S'`
CURRENT_HOST=`hostname`
CURRENT_HOST_SHORT=`hostname -s`
LOGS_FOLDER=${CASS_BACKUP_FOLDER}/logs
LOGFILE=${LOGS_FOLDER}/purge_backups_${CURRENT_DATETIME}.log
MEDUSA_LITE_EMAIL=/tmp/medusa_lite_email.txt

# pre-create logs folder and the log file
mkdir -p ${LOGS_FOLDER}
touch ${LOGFILE}


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


# generate backups report and store in log
CONFIG_FILE=${SCRIPT_FOLDER}/medusa_lite_list_backups.sh
source ${CONFIG_FILE} >> ${LOGFILE}


echo -e " " >> ${LOGFILE}
echo -e "PURGING FOLLOWING EXPIRED BACKUPS :" >> ${LOGFILE}


# handle expired backups
for eb in ${EXPIRED_BACKUP_TAGS}
do
  # report expired backup
  CURRENT_FOLDER=${BACKUPS_FOLDER}/${eb}
  echo -e "${CURRENT_FOLDER}" >> ${LOGFILE}

  # purge expired backup
  rm -Rf ${CURRENT_FOLDER}
done


# purge old logs
find ${LOGS_FOLDER} -name "*.log" -mtime +31 -delete;


##################################################
### final steps
##################################################

# record final log
echo -e " "                                                                >> ${LOGFILE}
echo -e `printf "%0.s-" {1..50}`                                           >> ${LOGFILE}
echo -e "purge_backups script started at : ${CURRENT_DATETIME_DISPLAY}"    >> ${LOGFILE}
echo -e "purge_backups script ended   at : `date +'%d-%b-%Y %I:%M:%S %p'`" >> ${LOGFILE}
echo -e `printf "%0.s-" {1..50}`                                           >> ${LOGFILE}

#############

