# Medusa_lite_forCassandraBackups

<br><br>
crontab entries :
```
$ crontab -e

##### add following lines
15 21 * * * sh ~/medusa_lite/medusa_lite_take_node_backup.sh
45 21 * * * sh ~/medusa_lite/medusa_lite_purge_backups.sh
```
