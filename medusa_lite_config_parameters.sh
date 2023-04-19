#############
#!/bin/bash

# medusa_lite config_file : v01_20230419 : Sarma Pydipally

### config parameters - start

CASS_DATA_BASE_FOLDER=/apps/opt/cassandra/data/data
CASS_BACKUP_FOLDER=/apps/opt/cassandra/cassandra_backups
CASS_BACKUP_PREFIX=snapshot_
NUMBER_OF_BACKUPS_TO_KEEP=7

# Email list for notifications (multiple email IDs in comma separated format)
TO_EMAIL_LIST=<email_1>,<email_2>,<email_3>
TO_PAGER_LIST=<pager_1>,<pager_2>

### config parameters - end

#############

