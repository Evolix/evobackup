#!/bin/bash
#!! Need export JAIL="jailName"


ipBackup1=198.51.100.10
ipBackup2=198.51.100.20

# Start jail.
echo -e "\e[34mStarting jail...\e[39m"
mount -t proc proc-chroot /backup/jails/$JAIL/proc/
mount -t devtmpfs udev /backup/jails/$JAIL/dev/
mount -t devpts devpts /backup/jails/$JAIL/dev/pts
chroot /backup/jails/$JAIL /usr/sbin/sshd > /dev/null
# Plan-sauvegardes.
echo -e "$(grep Port /backup/jails/$JAIL/etc/ssh/sshd_config |cut -d ' ' -f 2) $JAIL ($(grep AllowUsers /backup/jails/$JAIL/etc/ssh/sshd_config |cut -d ' ' -f 2 |cut -d '@' -f 2))\n" >> PLAN-SAUVEGARDES
# File for incs.
echo -e "\e[34mCreate file inc config...\e[39m"
cp inc.tpl /etc/evobackup/$JAIL
# iptables rules.
echo -e "\e[34mAdd iptables rule...\e[39m"
echo -e "# $JAIL\n/sbin/iptables -A INPUT -p tcp --sport 1024: --dport $(grep Port /backup/jails/${JAIL}/etc/ssh/sshd_config |cut -d ' ' -f 2) -s $(grep AllowUsers /backup/jails/${JAIL}/etc/ssh/sshd_config |cut -d ' ' -f 2 |cut -d '@' -f 2) -j ACCEPT" >> /etc/firewall.rc.jails
/etc/init.d/minifirewall restart

# Create the jail on the second server.
echo -e "\e[34mDeploy on second server...\e[39m"
rsync -a --exclude='var/backup/**' --exclude='proc/**' --exclude='dev/**' /backup/jails/$JAIL/ ${ipBackup2}:/backup/jails/$JAIL/
rsync -a /etc/evobackup/$JAIL ${ipBackup2}:/etc/evobackup/
rsync -a /etc/firewall.rc.jails ${ipBackup2}:/etc/
ssh ${ipBackup2} "
mount -t proc proc-chroot /backup/jails/$JAIL/proc/
mount -t devtmpfs udev /backup/jails/$JAIL/dev/
mount -t devpts devpts /backup/jails/$JAIL/dev/pts
chroot /backup/jails/$JAIL /usr/sbin/sshd > /dev/null
/etc/init.d/minifirewall restart
"
echo -e "\e[32mDone!\e[39m"

# Information to user

echo "You can add these iptables rules to backuped server:"
echo /sbin/iptables -A INPUT -p tcp --sport $(grep Port /backup/jails/${JAIL}/etc/ssh/sshd_config |cut -d ' ' -f 2) --dport 1024:65535 -s $ipBackup1 -m state --state ESTABLISHED,RELATED -j ACCEPT
echo /sbin/iptables -A INPUT -p tcp --sport $(grep Port /backup/jails/${JAIL}/etc/ssh/sshd_config |cut -d ' ' -f 2) --dport 1024:65535 -s $ipBackup2 -m state --state ESTABLISHED,RELATED -j ACCEPT
