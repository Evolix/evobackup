#!/bin/sh
# Update all OpenSSH chroot.

BACKUP_PATH='/backup/jails'

for i in `ls -1 ${BACKUP_PATH}/*/lib/libnss_compat.so.2`; do
        chrootdir=`echo $i | cut -d"/" -f1,2,3,4`
        echo -n "Updating $chrootdir ..."
        ./chroot-bincopy.sh $chrootdir
        echo "Done!"
done