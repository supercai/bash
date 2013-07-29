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
MYSQL_USR=$2
MYSQL_PASSWORD=$3
TIMESTAMP=`date +%F`
BACKUP_BASE_DIR=/data/backup/mysql
BACKUP_FULL_DIR=/data/backup/mysql/$TIMESTAMP
BACKUP_DIR=$MYSQL_DATABASE'_full_'$TIMESTAMP

if [ ! -d $BACKUP_FULL_DIR/$BACKUP_DIR ];then
	mkdir -p $BACKUP_FULL_DIR/$BACKUP_DIR
fi

echo "**********************start to make full backup****************************"

echo "full_backup `date +"%F %H:%M:%S"` `tail -n 1 $MYSQL_DATA_DIR/mysql-bin.index|cut -d/ -f2`" >> $BACKUP_BASE_DIR/backup.log

$MYSQL_DIR/bin/mysqlhotcopy -u $MYSQL_USR -p $MYSQL_PASSWORD $MYSQL_DATABASE $BACKUP_FULL_DIR/$BACKUP_DIR 2>$BACKUP_BASE_DIR/error.log
if [ $? -ne 0 ];then
	exit 2
	echo "$TIMESTAMP full_backup failed exit2 ">>$BACKUP_BASE_DIR/error.log
fi

cd $BACKUP_FULL_DIR
tar zcvf $BACKUP_FULL_DIR/$BACKUP_DIR.tar.gz $BACKUP_DIR 2>>$BACKUP_BASE_DIR/error.log
if [ $? -ne 0 ];then
	exit 3
	echo "$TIMESTAMP full_backup failed exit3 ">>$BACKUP_BASE_DIR/error.log
fi

rm -rf $BACKUP_FULL_DIR/$BACKUP_DIR 

echo "**********************full backup have finished*****************************"
