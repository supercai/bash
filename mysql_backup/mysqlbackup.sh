#!/bin/bash
if [ $# -lt 3 ];then
    echo "USAGE: $0 [Database] [user] [password]"
    echo "e.g: $0 mysql root ename110"
    echo "e.g: $0 mysql root ename110 /tmp/mysql.sockN"
    exit 1;
fi

BACKUP_CYCLE=7                                   # backup cycle in days
BACKUP_PATH=/data/backup/mysql/                  # the backup root dir
BIN_LOG=/data/log/mysql/binlog.[0-9]*            # mysql binlog path
MYSQLDUMP_BIN=/usr/local/mysql/bin/mysqldump
MYSQLBINLOG_BIN=/usr/local/mysql/bin/mysqlbinlog
MYSQLADMIN_BIN=/usr/local/mysql/bin/mysqladmin
MYSQL_SOCK=/tmp/mysql.sock
DB_NAME=$1
BACKUP_USER=$2
BACKUP_PASS=$3
DB_BACKUP_DIR=$BACKUP_PATH$DB_NAME/
DB_BACKUP_TEMP_DIR=$BACKUP_PATH$DB_NAME/temp/
DB_BACKUP_LOG_DIR=$BACKUP_PATH$DB_NAME/log/
FULL_BACKUP_LOG=$DB_BACKUP_LOG_DIR'full_backup.log'  # the name of full backup
INCR_BACKUP_LOG=$DB_BACKUP_LOG_DIR'incr_backup.log'
ERROR_BACKUP_LOG=$DB_BACKUP_LOG_DIR'error_backup.log'
CHECK_LAST_FULL_DATE=`date +"%Y-%m-%d" -d"-$BACKUP_CYCLE day"`
LAST_TWO_FULL_DATE=`date +"%Y-%m-%d" -d"-$(($BACKUP_CYCLE + $BACKUP_CYCLE)) day"`
IS_FULL_BACKUP_FLAG=0

# define MYSQL_SOCK
if [ ! -z $4 ]; then
    MYSQL_SOCK=$4
fi

# check database dir and the log files
if [ ! -d $DB_BACKUP_DIR ]
then
    mkdir -p $DB_BACKUP_DIR
    mkdir -p $DB_BACKUP_LOG_DIR
    mkdir -p $DB_BACKUP_TEMP_DIR
    echo $CHECK_LAST_FULL_DATE > $FULL_BACKUP_LOG
fi

LAST_FULL_DATE=`tail -n 1 $FULL_BACKUP_LOG`

# determine whether it is full backup
if [ `date -d "$LAST_FULL_DATE" +%s` -le `date -d "$CHECK_LAST_FULL_DATE" +%s` ]
then
    IS_FULL_BACKUP_FLAG=1
    if [ -d $DB_BACKUP_DIR$LAST_TWO_FULL_DATE ]; then
        rm -rf $DB_BACKUP_DIR$LAST_TWO_FULL_DATE
    fi
    LAST_FULL_DATE=`date +"%Y-%m-%d"`
fi

THE_FULL_BACKUP_DIR=$DB_BACKUP_DIR$LAST_FULL_DATE/

# if IS_FULL_BACKUP_FLAG is 1 then full backup
if [ $IS_FULL_BACKUP_FLAG = 1 ]
then
    mkdir -p $THE_FULL_BACKUP_DIR
    echo "Start to full backup database $DB_NAME..."
    echo $LAST_FULL_DATE > $FULL_BACKUP_LOG

    # backup INCR_BACKUP_LOG file
    # echo full_backup_datetime to a new incr_backup_log
    # this time equal to the last full backup datetime
    if [ -f $INCR_BACKUP_LOG ]; then
        mv $INCR_BACKUP_LOG "$INCR_BACKUP_LOG"_"$LAST_FULL_DATE"
    fi
    echo `date +"%Y-%m-%d %H:%M:%S"` >> $INCR_BACKUP_LOG

    # TODO test copy data file other than mysqldump
    #SQL_FILE=$THE_FULL_BACKUP_DIR$LAST_FULL_DATE.sql
    SQL_FILE=$DB_BACKUP_TEMP_DIR$LAST_FULL_DATE.sql

    # --opt
    # This option is shorthand; it is the same as specifying --add-drop-table --add-locks --create-options --disable-keys --extended-insert --lock-tables --quick --set-charset.
    #mysqldump -u$BACKUP_USER -p$BACKUP_PASS --flush-logs --lock-tables $DB_NAME > $SQL_FILE
    $MYSQLDUMP_BIN -u$BACKUP_USER -p$BACKUP_PASS -S$MYSQL_SOCK --flush-logs --opt -R $DB_NAME > $SQL_FILE 2> /tmp/mysqlbackup_stderr
    if [ "$?" -ne "0" ]; then
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 0: `cat /tmp/mysqlbackup_stderr`\n"
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 0: `cat /tmp/mysqlbackup_stderr`\n" >> $ERROR_BACKUP_LOG
        exit 4
    fi
    echo "Database $DB_NAME backup finish..."
else

    echo "Start to increment backup database $DB_NAME..."
    END_DATETIME=`date +"%Y-%m-%d %H:%M:%S"`
    FILENAME_END_DATETIME=`date +"%Y-%m-%d_%H:%M:%S"`

    START_DATETIME=x
    if [ -f $INCR_BACKUP_LOG ]
    then
        START_DATETIME=`tail -n 1 $INCR_BACKUP_LOG`
    fi

    if [ "$START_DATETIME" = x ]
    then
        #START_DATETIME=`date +"%Y-%m-%d %H:%M:%S" -d"-1 day"`
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 1: there is no START_DATETIME START_DATETIME = $START_DATETIME\n"
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 1: there is no START_DATETIME START_DATETIME = $START_DATETIME\n" >> $ERROR_BACKUP_LOG
        exit 1
    fi

    #SQL_FILE=$THE_FULL_BACKUP_DIR`date +"%Y-%m-%d_%H:%M:%S"`.sql
    SQL_FILE=$DB_BACKUP_TEMP_DIR$FILENAME_END_DATETIME.sql

    # purge binlog (not required now)
    # purge binlog in my.cnf with expire_logs_days = 7
    #PURGE_DATETIME=`echo "$START_DATETIME"|awk '{print $1}'`
    #mysql -u$BACKUP_USER -p$BACKUP_PASS -e "purge master logs before ${PURGE_DATETIME}"

    # flush-logs
    $MYSQLADMIN_BIN -u$BACKUP_USER -p$BACKUP_PASS -S$MYSQL_SOCK flush-logs 2> /tmp/mysqlbackup_stderr
    if [ "$?" -ne "0" ]; then
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 2: `cat /tmp/mysqlbackup_stderr`\n"
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 2: `cat /tmp/mysqlbackup_stderr`\n" >> $ERROR_BACKUP_LOG
        exit 2
    fi

    # wait a few moment for flush-logs
    sleep 5

    # export incr backup sql file
    $MYSQLBINLOG_BIN -u$BACKUP_USER -p$BACKUP_PASS -S$MYSQL_SOCK -d$DB_NAME $BIN_LOG --start-datetime="$START_DATETIME" --stop-datetime="$END_DATETIME" > $SQL_FILE 2> /tmp/mysqlbackup_stderr
    if [ "$?" -ne "0" ]; then
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 3: `cat /tmp/mysqlbackup_stderr`\n"
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` Backup error 3: `cat /tmp/mysqlbackup_stderr`\n" >> $ERROR_BACKUP_LOG
        exit 3
    fi

    echo $END_DATETIME >> $INCR_BACKUP_LOG

    echo "Database $DB_NAME backup finish..."
fi

# zip and encrypt sql file
ZIP_FILE=$THE_FULL_BACKUP_DIR${SQL_FILE##*/}.tar.gz
tar --force-local -czvf $ZIP_FILE -C $DB_BACKUP_TEMP_DIR ${SQL_FILE##*/} && rm -f $SQL_FILE
