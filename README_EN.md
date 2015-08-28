EvoBackup
=========

EvoBackup is a bunch of shell scripts to create a backup server which will
handle the backup of many servers (clients). Licence is GPLv2.

The main principle uses SSH chroot (called "jails" in the FreeBSD
world) for each client to backup. Each client will upload his data every day
using rsync in his chroot (using root account).
Incrementals are stored outside of the chroot using hard links. (So incrementals
are not available for clients). Using this method we can keep tens of backup of
each client securely and not using too much space.

                                    Backup server
                                    ************
Server 1 ------ SSH/rsync ------->  * tcp/2222 *
                                    *          *
Server 2 ------ SSH/rsync ------->  * tcp/2223 *
                                    ************

This method uses standard tools (ssh, rsync, cp -al). EvoBackup is used for
many years by Evolix for back up each day hundreds of servers which uses many
terabytes of data.

More documentation TODO…