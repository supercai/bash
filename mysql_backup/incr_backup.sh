#!/bin/bash
if [ $# -lt 3 ];then
	echo "failed to run $0"
	echo "USAGE: $0 [database] [user] [password]"
	echo "e.g: $0 msc root haoying123"
	exit 1
fi

MYSQL_DIR=/usr/local/mysql
#BIN_LOG_DIR=/data/mysql/var/mysql-bin.[0-9]*
MYSQL_DATA_DIR=/data/mysql/var
MYSQL_DATABASE=$1
MYSQL_USER=$2
MYSQL_PASSWORD=$3
BACKUP_BASE_DIR=/data/backup/mysql
TIMESTAMP=`sed -n '/full_backup/p' $BACKUP_BASE_DIR/backup.log|tail -n 1|awk '{print $2}'`
BACKUP_FULL_DIR=/data/backup/mysql/$TIMESTAMP
BACKUP_DIR=$MYSQL_DATABASE'_incr_'$(date +"%F").sql

START_BIN_LOG=`tail -n 1 $BACKUP_BASE_DIR/backup.log | awk '{print $4}'`
STOP_BIN_LOG=`tail -n 1 $MYSQL_DATA_DIR/mysql-bin.index | cut -d/ -f2`

if [ -z $TIMESTAMP ];then
	exit 2
fi

echo "incr_backup `date +"%F %H:%M:%S"` $STOP_BIN_LOG" >>$BACKUP_BASE_DIR/backup.log
#取时间戳
STARTTIME=`tail -n 2 $BACKUP_BASE_DIR/backup.log | head -n 1 | awk '{print $2" "$3}'`
STOPTIME=`tail -n 1 $BACKUP_BASE_DIR/backup.log | awk '{print $2" "$3}'`

echo "**********************start to make incremental backup****************************"
BINLOG=`sed -n '/'$START_BIN_LOG'/,$p' $MYSQL_DATA_DIR/mysql-bin.index |cut -d/ -f2 |tr -s "\n" " "`
cd $MYSQL_DATA_DIR
	$MYSQL_DIR/bin/mysqlbinlog -u$MYSQL_USER -p$MYSQL_PASSWORD $BINLOG --start-datetime="$STARTTIME" --stop-datetime="$STOPTIME" >> $BACKUP_FULL_DIR/$BACKUP_DIR 2>> $BACKUP_BASE_DIR/error.log

cd $BACKUP_FULL_DIR
tar zcvf $BACKUP_FULL_DIR/$BACKUP_DIR.tar.gz $BACKUP_DIR 2>> $BACKUP_BASE_DIR/error.log
if [ $? -ne 0 ];then
	exit 3
	echo " $(date +"%F") incr_backup failed exit3 " >> $BACKUP_BASE_DIR/error.log	
fi

rm -rf $BACKUP_FULL_DIR/$BACKUP_DIR 

echo "**********************incremental backup have finished*****************************"
