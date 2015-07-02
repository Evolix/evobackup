#!/bin/bash

# Gregory Colpart <reg@evolix.fr> & Benoit Serie <bserie@evolix.fr>
# Chroot script for EvoBackup/OpenSSH

# Tested only on Debian Wheezy/Jessie amd64
# Start:
#  chroot /backup/jails/myserver mount -t proc proc-chroot /proc/
#  chroot /backup/jails/myserver mount -t devtmpfs udev /dev/
#  chroot /backup/jails/myserver mount -t devpts devpts-chroot /dev/pts/
#  chroot /backup/jails/myserver /usr/sbin/sshd > /dev/null
# Reload:
#  kill -HUP $(chroot /backup/jails/myserver cat /var/run/sshd.pid)
# Stop:
#  kill -9 $(chroot /backup/jails/myserver cat /var/run/sshd.pid)
# Restart: 
#  kill -9 $(chroot /backup/jails/myserver cat /var/run/sshd.pid)
#  chroot /backup/jails/myserver /usr/sbin/sshd > /dev/null

# After *each* ssh upgrade or libs upgrade:
#  sh chroot-ssh.sh updateall
# And restart all sshd daemons

# We suppose jails are all in /backup/jails...
BACKUP_PATH='/backup/jails'

# Are we root?
id=$(id -u)
if [ $id != 0 ]; then
    echo "Error, you need to be root to install EvoBackup!"
    exit 1
fi

usage() {

    cat <<EOT

Add an OpenSSH chroot.
Usage: $0 -n chroot-name -i ip -p port -k pub-key-path

Mandatory parameters:
-n: name of chroot

Optional parameters:
-i: IP address of the client machine.
-k: Path to the SSH public key of the client machine.
-p: SSH port which chroot/jail will listen on.
    If you set "guess", port will be guessed if there is already one chroot.

EOT

}

bincopy() {

chrootdir=$1

# TODO : better detection of amd64 arch (or support only amd64...)
cp -f /lib/ld-linux.so.2 $chrootdir/lib/ 2>/dev/null \
    || cp -f /lib64/ld-linux-x86-64.so.2 $chrootdir/lib64/

release=$(lsb_release -s -c)
if [ "$release" = "squeeze" ]; then
    cp /lib/libnss* $chrootdir/lib/
else
    if [ "$release" = "wheezy" ]; then
        cp /lib/x86_64-linux-gnu/libnss* $chrootdir/lib/x86_64-linux-gnu/
    else
        # Others? Not tested...
        cp /lib/x86_64-linux-gnu/libnss* $chrootdir/lib/x86_64-linux-gnu/
    fi
fi

for dbin in /bin/bash /bin/cat /bin/chown /bin/mknod /bin/rm \
    /bin/sed /bin/sh /bin/uname /bin/mount /usr/bin/rsync /usr/sbin/sshd \
    /usr/lib/openssh/sftp-server; do

    cp -f $dbin $chrootdir/$dbin;
    for lib in $(ldd $dbin | grep -Eo "/.*so.[0-9\.]+"); do
        cp -p $lib $chrootdir/$lib
    done
done

}


while getopts ':n:i:p:k:' opt; do
    case $opt in
    n)
        jail=$OPTARG
    ;;
    i)
        ip=$OPTARG
    ;;
    p)
        port=$OPTARG
    ;;
    k)
        pub_key_path=$OPTARG
    ;;
    ?)
        usage
    exit 1
    ;;
    esac
done

# Complete path to chroot dir.
chrootdir=${BACKUP_PATH}/${jail}

# Verify parameters.
if [ -z $jail ];
then
    usage
    exit 1
fi
# Test if the chroot exists.
if [ -e $chrootdir ]; then
    echo "Error, directory to chroot already exists!"
    exit 1
fi
# Verify the presence of the public key.
if [ -n "$pub_key_path" ] && [ ! -f "$pub_key_path" ]; then
    echo "Public key $pub_key_path not found."
    exit 1
fi
# Try to guess the next SSH port.
if [ "$port" = "guess" ]; then
    port=$(grep -h Port ${BACKUP_PATH}/*/etc/ssh/sshd_config 2>/dev/null \
            | grep -Eo [0-9]+ | sort -n | tail -1)
    port=$((port+1)) 
    if [ ! $port -gt 1 ]; then
        echo "Sorry, port cannot be guessed."
        exit 1
    fi
fi

# Used for updating jails.
if [ "$jail" = "updateall" ]; then

    for i in $(ls -1 ${BACKUP_PATH}/*/lib/x86_64-linux-gnu/libnss_compat.so.2); do
        chrootdir=$(echo $i | cut -d"/" -f1,2,3,4)
        echo -n "Updating $chrootdir ..."
        bincopy $chrootdir
        echo "...Done!"
    done

else

# Creation of the jail.
mkdir -p $chrootdir
chown root:root $chrootdir
umask 022

echo -n "1 - Creating the chroot..."
mkdir -p $chrootdir/{bin,dev,etc/ssh,lib,lib64,proc}
mkdir -p $chrootdir/lib/{x86_64-linux-gnu,tls/i686/cmov,i686/cmov}
mkdir -p $chrootdir/usr/{bin,lib,sbin}
mkdir -p $chrootdir/usr/lib/{x86_64-linux-gnu,openssh,i686/cmov}
mkdir -p $chrootdir/root/.ssh && chmod 700 $chrootdir/root/.ssh
mkdir -p $chrootdir/var/{log,run/sshd}
touch $chrootdir/var/log/{authlog,lastlog,messages,syslog}
touch $chrootdir/etc/fstab
echo "...OK"

echo -n "2 - Copying essential files..."
cp /proc/devices $chrootdir/proc
cp /etc/ssh/{ssh_host_rsa_key,ssh_host_dsa_key} $chrootdir/etc/ssh/
cp etc/sshd_config $chrootdir/etc/ssh/
cp etc/passwd $chrootdir/etc/
cp etc/shadow $chrootdir/etc/
cp etc/group  $chrootdir/etc/
echo "...OK"

echo -n "3 - Copying binaries..."
bincopy $chrootdir
echo "...OK"

echo -n "4 - Configuring the chroot..."
[ -n "$port" ] && [ "$port" != "guess" ] && sed -i "s/^Port 2222/Port ${port}/" ${chrootdir}/etc/ssh/sshd_config
[ -n "$ip" ] && sed -i "s/IP/$ip/g" ${chrootdir}/etc/ssh/sshd_config
touch ${chrootdir}/root/.ssh/authorized_keys && chmod 600 ${chrootdir}/root/.ssh/authorized_keys && chown -R root:root ${chrootdir}/root/.ssh/
[ -n "$pub_key_path" ] && cat $pub_key_path >> ${chrootdir}/root/.ssh/authorized_keys
echo "...OK"

echo ""
echo "Done. OpenSSH chroot added! Restart evobackup service."
echo ""

fi

