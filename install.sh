#!/bin/bash
# Install EvoBackup configuration and init files.

# Debian or Ubuntu?
flavor=$(lsb_release -i -s)
debian=false
ubuntu=false
if [ "$flavor" = "Debian" ]; then
    echo "Debian detected."
    debian=true
elif [ "$flavor" = "Ubuntu" ]; then
    echo "Ubuntu detected."
    ubuntu=true
else
    echo "Not a Debian based distribution? If yes, fix this script. Exiting..."
    exit 1
fi

# Are we root?
id=$(id -u)
if [ $id != 0 ]; then
    echo "Error, you need to be root to install EvoBackup!"
    exit 1
fi

cp -r install/etc/evobackup /etc/
# Don't install init script for client-side.
if [ "$1" != "client" ]; then
    $debian && cp install/etc/init.d/evobackup /etc/init.d/
    $ubuntu && cp install/etc/init/evobackup.conf /etc/init/
fi

echo "Done."
exit 0