#!/bin/sh
# Set-up and configure an OpenSSH chroot.

BACKUP_PATH='/backup/jails'

#Are we root?
id=$(id -u)
if [ $id != 0 ]; then
    echo "Error, you need to be root to install EvoBackup!"
    exit 1
fi

usage() {

    cat <<EOT
Add an OpenSSH chroot.
Usage: $0 -n name -i ip -p port -k pub-key-path

Mandatory parameters:
-n: Name of the chroot.
-i: IP address of the client machine.
-k: Path to the SSH public key of the client machine.

Optional parameters:
-p: SSH port which chroot/jail will listen on.
    port can be ommited if there is already one chroot, it will be guessed.
EOT

}



newchroot() {

    # Path to the chroot.
    chrootdir=$1
    mkdir -p $chrootdir
    chown root:root $chrootdir
    umask 022
    # create jail
    echo -n "1 - Creating the chroot..."
    mkdir -p $chrootdir/{bin,dev,etc/ssh,lib,lib64,proc}
    mkdir -p $chrootdir/lib/{x86_64-linux-gnu,tls/i686/cmov,i686/cmov}
    mkdir -p $chrootdir/usr/{bin,lib,sbin}
    mkdir -p $chrootdir/usr/lib/{x86_64-linux-gnu,openssh,i686/cmov}
    mkdir -p $chrootdir/root/.ssh
    mkdir -p $chrootdir/var/{log,run/sshd}
    touch $chrootdir/var/log/{authlog,lastlog,messages,syslog}
    touch $chrootdir/etc/fstab
    echo "...OK"

    echo -n "2 - Copying essential files..."
    cp /proc/devices $chrootdir/proc
    cp /etc/ssh/{ssh_host_rsa_key,ssh_host_dsa_key} $chrootdir/etc/ssh/
    cp chroot-etc/sshd_config $chrootdir/etc/ssh/
    cp chroot-etc/passwd $chrootdir/etc/
    cp chroot-etc/shadow $chrootdir/etc/
    cp chroot-etc/group  $chrootdir/etc/
    echo "...OK"

    echo -n "3 - Copying binaries..."
    ./chroot-bincopy.sh $chrootdir
    echo "...OK"
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

# Verify parameters.
if [ -z $jail ] || [ -z $ip ] || [ -z $pub_key_path ];
then
    usage
    exit 1
fi
# Test if the chroot exists.
if [ -d ${BACKUP_PATH}/${jail} ]; then
    echo "Error, directory to chroot already exists!"
    exit 1
fi
# Verify the presence of the public key.
if [ ! -f "$pub_key_path" ]; then
    echo "Public key $pub_key_path not found."
    exit 1
fi
# If port ommited try to guess it.
if [ -z $port ]; then
    port=$(grep -h Port /backup/jails/*/etc/ssh/sshd_config \
            | grep -Eo [0-9]+ | sort -n | tail -1)
    port=$((port+1))
    if [ -z $port ]; then
        echo "Port cannot be guessed. Add -p option!"
        exit 1
    fi
fi

# Create the chroot
newchroot ${BACKUP_PATH}/${jail}
# Configure the chroot
echo -n "4 - Configuring the chroot..."
sed -i "s/^Port 2222/Port ${port}/" ${BACKUP_PATH}/${jail}/etc/ssh/sshd_config
sed -i "s/IP/$ip/g" ${BACKUP_PATH}/${jail}/etc/ssh/sshd_config
cat $pub_key_path > ${BACKUP_PATH}/${jail}/root/.ssh/authorized_keys
chmod -R 600 ${BACKUP_PATH}/${jail}/root/.ssh/
chown -R root:root ${BACKUP_PATH}/${jail}/root/.ssh/
cat <<EOT >/etc/evobackup/conf.d/incs/${jail}
+%Y-%m-%d.-0day
+%Y-%m-%d.-1day
+%Y-%m-%d.-2day
+%Y-%m-%d.-3day
+%Y-%m-01.-0month
+%Y-%m-01.-1month
EOT

echo -n "Done. OpenSSH chroot added! Restart evobackup service."