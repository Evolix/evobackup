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

```
                                    Backup server
                                    ************
Server 1 ------ SSH/rsync ------->  * tcp/2222 *
                                    *          *
Server 2 ------ SSH/rsync ------->  * tcp/2223 *
                                    ************
```

This method uses standard tools (ssh, rsync, cp -al). EvoBackup is used for
many years by Evolix for back up each day hundreds of servers which uses many
terabytes of data.

Backup server
-------------

The backup server need to be based on Debian. Tested on Debian Wheezy and
Ubuntu 13.04.

Needed packages:

* openssh-server
* rsync
* bsd-mailx (or other package providing /usr/bin/mailx)

Backups are stored in a big partition mounted on /backup (you can change this).
For security reasons it is recommended to encrypt the backup partition (i.e
using LUKS).

Main directories:

* /backup/jails: chroot used by clients
* /backup/incs: incrementals
* /etc/evobackup: Config dir

To install and configure EvoBackup read INSTALL.md