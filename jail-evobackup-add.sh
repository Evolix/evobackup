#!/bin/sh

BACKUP_ROOT='/backup'

function usage {
    cat <<EOT >&2
Add an evobackup jail.
Usage : $0 -n name -i ip -p port -k pub-key-path
All these options are required
  -n  :  name of the jail
  -i  :  IP address of client machine
  -p  :  SSH port where jail listen on
  -k  :  path to the SSH public key of the client machine
EOT
}

while getopts ':n:i:p:k:' o
do
    case $o in
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

if [ -z $jail ] || [ -z $ip ] || [ -z $port ] || [ -z $pub_key_path ]; then
    usage
    exit 1
fi

if [ ! -f "$pub_key_path" ]; then
    echo "public key file $pub_key_path not found."
    exit 1
fi

if [ ! -f 'chroot-ssh.sh' ]; then
    echo 'script chroot-ssh.sh not found, make sure you are in the correct directory!'
    exit 1
fi


sh chroot-ssh.sh $BACKUP_ROOT/jails/$jail

sed -i "s/^Port 2222/Port $port/" $BACKUP_ROOT/jails/$jail/etc/ssh/sshd_config
sed -i "s/IP/$ip/g" $BACKUP_ROOT/jails/$jail/etc/ssh/sshd_config

cat $pub_key_path >> $BACKUP_ROOT/jails/$jail/root/.authorized_keys
chmod -R 600 $BACKUP_ROOT/jails/$jail/root/.ssh/
chown -R root:root $BACKUP_ROOT/jails/$jail/root/.ssh/

# TODO: Modif sur le /etc/init.d/ssh...

mount -t proc proc-chroot /backup/jails/$jail/proc/
mount -t devpts devpts-chroot /backup/jails/$jail/dev/pts/
chroot /backup/jails/$jail /usr/sbin/sshd

cat <<EOT >/etc/evobackup/$jail
+%Y-%m-%d.-0day
+%Y-%m-%d.-1day
+%Y-%m-%d.-2day
+%Y-%m-%d.-3day
+%Y-%m-01.-0month
+%Y-%m-01.-1month
EOT
