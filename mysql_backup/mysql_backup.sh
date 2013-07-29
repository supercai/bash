#!/bin/bash
host=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#全备标志 1-增备 2-全备
backup_full=2
#获取备份日期
backup_date=`date "+%F"`
#获取备份6天后日期
backup_date_after=`date "+%F" --date="6 days"`
#获取备份目录
backup_dir=test
#全备时间文件，根据该文件的日期可以知道增备应该存在什么位置
backup_date_dir_log=$backup_dir/fulldir.log
#数据备份目录(包括全备和增备)
backup_full_root_dir=$backup_dir/$backup_date
#数据全备目录
backup_full_dir=$backup_full_root_dir/fulldir
#备份数据存放目录
backup_save_dir=$backup_full_root_dir/$backup_date
#备份详细日志记录文件
backup_log_file=$backup_save_dir/$backup_date.log

#my.cnf
cnf_path=/etc/my.cnf
#mysql备份帐号
backup_user=root
#mysql备份密码
backup_pwd="ename110"
#全备周期描述
range_time=518400

echo "##################Mysql备份##################"
echo "日期：$backup_date"
echo "主机：$host"
echo "-------------------------------------------"

if [ -f $backup_date_dir_log ]
then
last_full_backup=`cat $backup_date_dir_log`

last_time=`date -d $last_full_backup +%s`
now_time=`date +%s`
backup_flag=2
if [ `expr $now_time - $last_time` -le $range_time ]
then
backup_flag=1
fi

if [ $backup_flag -eq 1 ]
then
backup_full=1
fi
fi

check_dir=$backup_save_dir
if [ $backup_full -eq 2 ]
then
echo "######本次备份为全备#####"
check_dir=$backup_full_dir
if [ -d $check_dir ]
then
echo "$backup_date已经备份过，请检查，本次备份取消"
exit
fi
else
echo "#####本次备份为增备#####"
backup_full_root_dir=$backup_dir/$last_full_backup
fi


if [ $backup_full -eq 2 ]
then
mkdir -p $check_dir
echo "开始执行全备命令"
innobackupex --user=$backup_user --password=$backup_pwd --defaults-file=$cnf_path $backup_full_dir

if [[ $? -eq 0 ]]
then
echo $backup_date > $backup_date_dir_log
echo "日期：$backup_date全备完成..."
else
echo "[FAIL]日期：$backup_date全备失败，请检查..."
fi
else
backup_full_dir=$backup_full_root_dir/fulldir/`ls $backup_full_root_dir/fulldir`
backup_save_dir=$backup_full_root_dir/$backup_date
mkdir -p $backup_save_dir
echo "开始执行增备命令"
innobackupex --user=$backup_user --password=$backup_pwd --defaults-file=$cnf_path --incremental --incremental-basedir=$backup_full_dir $backup_save_dir
if [[ $? -eq 0 ]]
then
echo "日期：$backup_date增备完成..."
else
echo "[FAIL]日期：$backup_date增备失败，请检查..."
fi
fi
