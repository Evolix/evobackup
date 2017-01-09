#!/bin/bash

dir=`dirname $0`

if [ ! -f /etc/default/evobackup ]; then
	install -m 0644 -v $dir/tpl/evobackup.conf /etc/default/evobackup
fi
source /etc/default/evobackup

grep -q usr /etc/fstab
if [ $? == 0 ]; then
	mount -o remount,rw /usr
fi

mkdir -m 0755 -p $TPLDIR $LOG_DIR
cp -v $dir/tpl/* $TPLDIR
install -m 0755 -v $dir/bkctld /usr/local/sbin/

crontab -l|grep -q bkctld
if [ $? != 0 ]; then
	(crontab -l 2>/dev/null; echo "29 10 * * * bkctld inc && bkctld rm") | crontab -
fi

dpkg -l sysvinit >/dev/null
if [ $? == 0 ]; then
	install -m 0755 -v $dir/tpl/evobackup /etc/init.d/evobackup
	insserv evobackup
fi

dpkg -l systemd >/dev/null
if [ $? == 0 ] ; then
	#cp evobackup@.service /etc/systemd/system/evobackup@.service
	install -m 0755 -v $dir/tpl/evobackup /etc/init.d/evobackup
	systemctl enable evobackup
fi
