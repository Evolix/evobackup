#!/bin/bash

dir=`dirname $0`

cp $dir/evobackup.conf /etc/default/evobackup
source /etc/default/evobackup

grep -q usr /etc/fstab
if [ $? == 0 ]; then
	mount -o remount,rw /usr
fi

mkdir -p $TPLDIR
cp $dir/etc/* $TPLDIR
cp $dir/bkctl /usr/local/sbin/

crontab -l|grep -q bkctl
if [ $? != 0 ]; then
	(crontab -l 2>/dev/null; echo "29 10 * * * bkctl inc && bkctl rm") | crontab -
fi

dpkg -l sysvinit >/dev/null
if [ $? == 0 ]; then
	cp $dir/evobackup /etc/init.d/evobackup
	insserv evobackup
fi

dpkg -l systemd >/dev/null
if [ $? == 0 ] ; then
	#cp evobackup@.service /etc/systemd/system/evobackup@.service
	cp $dir/evobackup /etc/init.d/evobackup
	systemctl enable evobackup
fi
