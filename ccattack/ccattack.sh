#!/bin/bash
# iptables -I INPUT -p tcp --dport 80 -m connlimit --connlimit-above 120 -j REJECT
if [ $# -lt 1 ]
then
	echo "Failed to run "
	echo "USAGE : $0 [PATH] "
	echo "e.g $0 /var/log/nginx/host.access.log "
	exit 1
fi

log=$1
dir=$(cd `dirname $0`;pwd)
timestamp="26/Jul/2013:16:19:44"
bandcount=60

if [ -f $dir/black.list ]
then
	touch $dir/black.list
fi
if [ -f $dir/white.list ]
then
	touch $dir/white.list
fi

sed "1,\%$timestamp%d" $log|awk '{print $1}'|sort|uniq -c|sort -nr >$dir/count.tmp

if  
iptables -L http-blacklist -n >/dev/null
then
	:
else
	iptables -N http-blacklist
	iptables -A INPUT -j http-blacklist
fi

while read count ip
do 
	echo "$count"
	if [ $count -gt $bandcount ] 
	then
		if 
		grep $ip $dir/black.list >/dev/null
		then
			:
		else
			echo $ip >> $dir/black.list
		fi
	fi
done < $dir/count.tmp

while read ip
do 
	if 
	grep $ip $dir/white.list >/dev/null
	then
		:
	else
		if
		iptables -L http-blacklist -n|grep $ip >/dev/null
		then
			:
		else
			iptables -I http-blacklist -p tcp --src $ip --dport 80 -j DROP
		fi
	fi
done < $dir/black.list

while read ip
do 	
	if 
	iptables -L http-blacklist -n |grep $ip >/dev/null
	then
		iptables -D http-blacklist -p tcp --src $ip --dport 80 -j DROP
	fi
done < $dir/white.list

newtimestamp=`tail -n 1 $log|awk '{print $4}'|tr -d [`
sed -i "s#^timestamp=.*#timestamp=\"$newtimestamp\"#" $dir/ccattack.sh
