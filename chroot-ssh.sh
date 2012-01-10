#!/bin/bash

# Gregory Colpart <reg@evolix.fr>
# chroot script for OpenSSH
# $Id: chroot-ssh.sh,v 1.12 2010-07-02 17:40:29 gcolpart Exp $

# tested on Debian Etch and recently on Lenny
# Exec this script for jail creation:
# ./chroot-ssh.sh /backup/jails/myserver 
# Note: etc/{sshd_config,group,passwd} files should be present

# For Etch
# Start: chroot /backup/jails/myserver /usr/sbin/sshd > /dev/null
# Reload: kill -HUP `chroot /backup/jails/myserver cat /var/run/sshd.pid`
# Stop: kill -9 `chroot /backup/jails/myserver cat /var/run/sshd.pid`
# Restart: Stop + Start

# For Lenny
# Start :
#  chroot /backup/jails/myserver mount -t proc proc-chroot /proc/
#  chroot /backup/jails/myserver mount -t devpts devpts-chroot /dev/pts/
#  chroot /backup/jails/myserver /usr/sbin/sshd > /dev/null
# Reload: kill -HUP `chroot /backup/jails/myserver cat /var/run/sshd.pid`
# Stop: kill -9 `chroot /backup/jails/myserver cat /var/run/sshd.pid`
# Restart: 
#  kill -9 `chroot /backup/jails/myserver cat /var/run/sshd.pid`
#  chroot /backup/jails/myserver /usr/sbin/sshd > /dev/null

# After *each* ssh upgrade or libs upgrade:
# sh chroot-ssh.sh updateall
# And restart all sshd daemons

bincopy() {

chrootdir=$1

# TODO : better detection of amd64 arch
cp -f /lib/ld-linux.so.2 $chrootdir/lib/ || cp -f /lib64/ld-linux-x86-64.so.2 $chrootdir/lib64/
cp /lib/libnss* $chrootdir/lib/

for dbin in /bin/bash /bin/cat /bin/chown /bin/mknod /bin/rm /bin/sed /bin/sh /bin/uname /bin/mount /usr/bin/rsync /usr/sbin/sshd /usr/lib/openssh/sftp-server; do
    cp -f $dbin $chrootdir/$dbin;
    # (comme dans http://www.gcolpart.com/hacks/chroot-bind.sh)
    for lib in `ldd $dbin | cut -d">" -f2 | cut -d"(" -f1`; do
        cp -p $lib $chrootdir/$lib
    done
done

}

# synopsis
if [ $# -ne 1 ]; then
	echo "Vous devez indiquer un repertoire."
	echo "Exemple : chroot-ssh.sh /backup/jails/myserver"
	exit 0
fi

# are u root?
if [ `whoami` != "root" ]; then
	echo "Vous devez executer le script en étant root."
	exit 0
fi


if [ -e $1 ]; then
	echo "Le repertoire $1 existe deja..."
fi

if [ "$1" = "updateall" ]; then

    for i in `ls -1 /backup/jails/*/lib/libnss_compat.so.2`; do
        chrootdir=`echo $i | cut -d"/" -f1,2,3,4`
        echo -n "MaJ $chrootdir ..."
        bincopy $chrootdir
        echo "...OK"
    done

else

# where is jail
chrootdir=$1

mkdir -p $chrootdir
chown root:root $chrootdir

# create jail

echo -n "1 - Creation de la prison..."

	mkdir -p $chrootdir/{bin,dev,etc/ssh,lib,lib64}
	mkdir -p $chrootdir/lib/tls/i686/cmov/
	mkdir -p $chrootdir/proc
	mkdir -p $chrootdir/root/.ssh
	mkdir -p $chrootdir/usr/lib/i686/cmov/
	mkdir -p $chrootdir/lib/i686/cmov/
	mkdir -p $chrootdir/usr/{bin,lib,sbin}
	mkdir -p $chrootdir/usr/lib/openssh
	mkdir -p $chrootdir/var/log/
	mkdir -p $chrootdir/var/run/sshd

	touch $chrootdir/var/log/{authlog,lastlog,messages,syslog}
	touch $chrootdir/etc/fstab

echo "...OK"

echo -n "2 - Copie des donnees..."
	cp /proc/devices $chrootdir/proc

	cp /etc/ssh/{ssh_host_rsa_key,ssh_host_dsa_key} $chrootdir/etc/ssh/
	cp etc/sshd_config $chrootdir/etc/ssh/
	cp etc/passwd $chrootdir/etc/
	cp etc/shadow $chrootdir/etc/
	cp etc/group  $chrootdir/etc/

echo ".......OK"

echo -n "3 - Copie des binaires..."

bincopy $chrootdir

echo "......OK"

echo -n "4 - Creation des devices..."
	cd $chrootdir/dev/

	MAKEDEV {null,random,urandom,pty}
	mkdir pts
	#mknod ptmx c 5 2

echo "....OK"

echo -n "5 - Termine."

# end

echo ""

fi

