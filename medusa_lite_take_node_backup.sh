#############
#!/bin/bash

### https://github.com/sarma1807/medusa_lite-forCassandraBackups
# medusa_lite for Cassandra Backups
# script version : v01_20230419 : Sarma Pydipally

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
BACKUP_TAG=${CASS_BACKUP_PREFIX}${CURRENT_DATETIME}
LOGFILE=${LOGS_FOLDER}/${BACKUP_TAG}.log
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
  
  ### prepare email
  echo -e "From: ${CURRENT_HOST}\nTo: ${TO_EMAIL_LIST}\nSubject: $(basename "$0") failed on ${CURRENT_HOST}\nContent-Type: text/html\n\n" > ${MEDUSA_LITE_EMAIL}
  echo -e "<html><body>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "<h3> <font color=RED> Cassandra is DOWN. <BR><BR> ${BASH_SOURCE[0]} <BR> Script failed with ERRORs. </font> </h3>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "</body></html>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "<br><br>Report generated on ${CURRENT_HOST} @ `date +'%Y-%m-%d %H:%M:%S'` \n\n" >> ${MEDUSA_LITE_EMAIL}
  ### send email
  cat ${MEDUSA_LITE_EMAIL} | /usr/sbin/sendmail -t
  rm -f ${MEDUSA_LITE_EMAIL}

  exit 1
fi

### identify if "tree" command is missing
if ! command -v tree &> /dev/null
then
  ### "tree" command is missing on this machine
  echo "`date +'%d-%b-%Y %I:%M:%S %p'` : 'tree' command is missing on this machine. Script will NOT execute." >> ${LOGFILE}
  
  ### prepare email
  echo -e "From: ${CURRENT_HOST}\nTo: ${TO_EMAIL_LIST}\nSubject: $(basename "$0") failed on ${CURRENT_HOST}\nContent-Type: text/html\n\n" > ${MEDUSA_LITE_EMAIL}
  echo -e "<html><body>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "<h3> <font color=RED> 'tree' command is missing. <BR><BR> ${BASH_SOURCE[0]} <BR> Script failed with ERRORs. </font> </h3>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "</body></html>\n" >> ${MEDUSA_LITE_EMAIL}
  echo -e "<br><br>Report generated on ${CURRENT_HOST} @ `date +'%Y-%m-%d %H:%M:%S'` \n\n" >> ${MEDUSA_LITE_EMAIL}
  ### send email
  cat ${MEDUSA_LITE_EMAIL} | /usr/sbin/sendmail -t
  rm -f ${MEDUSA_LITE_EMAIL}

  exit 1
fi


##################################################
### start backup process
##################################################

# create backup folder
CURRENT_BACKUP_FOLDER=${CASS_BACKUP_FOLDER}/${CASS_CLUSTER_NAME}/${CURRENT_HOST_SHORT}/${BACKUP_TAG}
BACKUP_CQL_FOLDER=${CURRENT_BACKUP_FOLDER}/00_cql_scripts
mkdir -p ${BACKUP_CQL_FOLDER}


# record log
echo -e `printf "%0.s-" {1..50}`                                     >> ${LOGFILE}
echo -e "cassandra cluster name      : ${CASS_CLUSTER_NAME}"         >> ${LOGFILE}
echo -e "${CASS_VERSION}"                                            >> ${LOGFILE}
echo -e "backup executed on          : ${CURRENT_HOST}"              >> ${LOGFILE}
echo -e "backup tag                  : ${BACKUP_TAG}"                >> ${LOGFILE}
echo -e "script execution started at : ${CURRENT_DATETIME_DISPLAY}"  >> ${LOGFILE}
echo -e `printf "%0.s-" {1..50}`                                     >> ${LOGFILE}


# clear old snapshot if it already exists with same name
echo -e "CLEAR OLD SNAPSHOTs :"                                 >> ${LOGFILE}
echo -e "`date +'%I:%M:%S %p'` : starting  nodetool clearsnapshot command, if snapshot already exists with same tag" >> ${LOGFILE}
nodetool clearsnapshot -t ${BACKUP_TAG} > /dev/null
echo -e "`date +'%I:%M:%S %p'` : completed nodetool clearsnapshot command" >> ${LOGFILE}
echo -e `printf "%0.s-" {1..25}`                                >> ${LOGFILE}


##################################################
### generate cql scripts
##################################################

echo -e "CQL SCRIPTs :"                                         >> ${LOGFILE}

# capture full schema cql
FULL_SCHEMA_SCRIPT=00_FULL_schema.cql
cqlsh --execute="DESCRIBE SCHEMA ;" > ${BACKUP_CQL_FOLDER}/${FULL_SCHEMA_SCRIPT}
echo -e "`date +'%I:%M:%S %p'` : generated cql script for full schema and saved to ${BACKUP_CQL_FOLDER}/${FULL_SCHEMA_SCRIPT}" >> ${LOGFILE}

# capture CREATE KEYSPACE commands
CREATE_KS_SCRIPT=01_CREATE_KEYSPACEs.cql
grep -i "CREATE KEYSPACE" ${BACKUP_CQL_FOLDER}/${FULL_SCHEMA_SCRIPT} > ${BACKUP_CQL_FOLDER}/${CREATE_KS_SCRIPT}
echo -e "`date +'%I:%M:%S %p'` : generated cql script for CREATE KEYSPACEs and saved to ${BACKUP_CQL_FOLDER}/${CREATE_KS_SCRIPT}" >> ${LOGFILE}

# capture cql for each keyspace
CQL_KEYSPACES=`cqlsh --execute="DESCRIBE KEYSPACES ;" | xargs`
echo -e "`date +'%I:%M:%S %p'` : KEYSPACES FOUND : ${CQL_KEYSPACES}" >> ${LOGFILE}
echo -e "Total User Keyspaces : `wc -l ${BACKUP_CQL_FOLDER}/${CREATE_KS_SCRIPT} | cut -d" " -f1`" >> ${LOGFILE}
for KS in ${CQL_KEYSPACES}
do
  TMP_CQL_CMD="cqlsh --execute='DESCRIBE KEYSPACE \"${KS}\" ;'"
  eval "${TMP_CQL_CMD}" > ${BACKUP_CQL_FOLDER}/${KS}_schema.cql
done
echo -e "`date +'%I:%M:%S %p'` : generated cql scripts for each keyspace and saved them to ${BACKUP_CQL_FOLDER}/<KEYSPACE_NAME>_schema.cql" >> ${LOGFILE}
echo -e `printf "%0.s-" {1..25}`                                >> ${LOGFILE}


##################################################
### generate backup
##################################################

# do snapshot
echo -e "CREATE SNAPSHOTS :"                                          >> ${LOGFILE}
echo -e "`date +'%I:%M:%S %p'` : starting  nodetool snapshot command" >> ${LOGFILE}
nodetool snapshot --tag ${BACKUP_TAG} > /dev/null
echo -e "`date +'%I:%M:%S %p'` : completed nodetool snapshot command" >> ${LOGFILE}
SNAPSHOT_SUMMARY_FILE=${CURRENT_BACKUP_FOLDER}/01_snapshot_summary.txt
nodetool listsnapshots | egrep -i "Snapshot name|${BACKUP_TAG}" > ${SNAPSHOT_SUMMARY_FILE}
echo -e "`date +'%I:%M:%S %p'` : nodetool snapshot summary was saved to ${SNAPSHOT_SUMMARY_FILE}" >> ${LOGFILE}

# capture snapshot folder list
SOURCE_FOLDERS_FILE=${CURRENT_BACKUP_FOLDER}/02_source_folders.txt
tree -dfin --prune ${CASS_DATA_BASE_FOLDER} | grep ${BACKUP_TAG} > ${SOURCE_FOLDERS_FILE}

# process each source snapshot folder
TARGET_FOLDERS_FILE=${CURRENT_BACKUP_FOLDER}/03_folder_move_list.txt
MOVE_SNAPSHOTS_CMDS=${CURRENT_BACKUP_FOLDER}/04_move_snapshots.sh
rm -f ${MOVE_SNAPSHOTS_CMDS}
# SOURCE_FOLDERS=`cat ${SOURCE_FOLDERS_FILE} | grep umprmhdevgno`
SOURCE_FOLDERS=`cat ${SOURCE_FOLDERS_FILE}`
TMP_SNAP_SUFFIX=snapshots/${BACKUP_TAG}
for SF in ${SOURCE_FOLDERS}
do
  TMP_SNAP_PREFIX_REMOVED=${SF#"${CASS_DATA_BASE_FOLDER}"}
  TMP_SNAP_SUFFIX_REMOVED=${TMP_SNAP_PREFIX_REMOVED%"${TMP_SNAP_SUFFIX}"}
  TARGET_SNAPSHOT_FOLDER=${CURRENT_BACKUP_FOLDER}/${TMP_SNAP_SUFFIX_REMOVED}
  echo "${SF} -> ${TARGET_SNAPSHOT_FOLDER}" >> ${TARGET_FOLDERS_FILE}
  echo "mv ${SF} ${TARGET_SNAPSHOT_FOLDER}" >> ${MOVE_SNAPSHOTS_CMDS}
done
echo -e "`date +'%I:%M:%S %p'` : move snapshots script was saved to ${MOVE_SNAPSHOTS_CMDS}" >> ${LOGFILE}


# create final folders to store backups
for KS in ${CQL_KEYSPACES}
do
  TMP_MKDIR_CMD="mkdir -p ${CURRENT_BACKUP_FOLDER}/${KS}"
  eval "${TMP_MKDIR_CMD}"
done
echo -e `printf "%0.s-" {1..25}`                                         >> ${LOGFILE}
echo -e "MOVE SNAPSHOTS TO BACKUP FOLDERS :"                             >> ${LOGFILE}
echo -e "`date +'%I:%M:%S %p'` : created final folders to store backups" >> ${LOGFILE}


# move snapshots to backup folder
echo -e "`date +'%I:%M:%S %p'` : starting  move snapshots to backup folder" >> ${LOGFILE}
source ${MOVE_SNAPSHOTS_CMDS} > /dev/null
echo -e "`date +'%I:%M:%S %p'` : completed move snapshots to backup folder" >> ${LOGFILE}
echo -e "Backup Folder : ${CURRENT_BACKUP_FOLDER}"                          >> ${LOGFILE}
TMP_BACKUP_SIZE=`du -hx --max-depth=1 ${CURRENT_BACKUP_FOLDER} | tail -1 | cut -f1`
echo -e "Backup Size : ${TMP_BACKUP_SIZE}"                                  >> ${LOGFILE}


##################################################
### final steps
##################################################

# record final log
echo -e `printf "%0.s-" {1..50}`                                >> ${LOGFILE}
echo -e "backup started  at : ${CURRENT_DATETIME_DISPLAY}"      >> ${LOGFILE}
echo -e "backup ended    at : `date +'%d-%b-%Y %I:%M:%S %p'`"   >> ${LOGFILE}
echo -e `printf "%0.s-" {1..50}`                                >> ${LOGFILE}

#############

