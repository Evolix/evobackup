#!/bin/bash
# Copy essential binaries into the chroot.

chrootdir=$1

# TODO: better detection of amd64 arch
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
    for lib in `ldd $dbin | cut -d">" -f2 | cut -d"(" -f1`; do
        cp -p $lib $chrootdir/$lib
    done
done