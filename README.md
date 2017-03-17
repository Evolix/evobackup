Bkctld (aka evobackup)
=========

Bkctld is a shell script to create and manage a backup server which will
handle the backup of many servers (clients). Licence is AGPLv3.

The main principle uses SSH chroot (called "jails" in the FreeBSD
world) for each client to backup. Each client will upload his data every day
using rsync in his chroot (using root account).
Incrementals are stored outside of the chroot using hard links or btrfs snapshots.
(So incrementals are not available for clients). Using this method we can keep tens 
of backup of each client securely and not using too much space.

~~~
                                    Backup server
                                    ************
Server 1 ------ SSH/rsync ------->  * tcp/2222 *
                                    *          *
Server 2 ------ SSH/rsync ------->  * tcp/2223 *
                                    ************
~~~

This method uses standard tools (ssh, rsync, cp -al, btrfs subvolume). EvoBackup 
is used for many years by Evolix for back up each day hundreds of servers which
 uses many terabytes of data.

bkctld was test on Debian Jessie. It can be compatible with other Debian version
or derivated distribution like Ubuntu or Debian Wheezy.

A big size volume must be mount on /backup, we recommend usage of **btrfs** for
subvolume and snapshot fonctionnality.
This volume can be encrypted by **luks** for security reason.

## Install

A Debian package is available in Evolix repository

~~~
echo "http://pub.evolix.net/ jessie/" >> /etc/apt/sources.list
apt update
apt install bkctld
~~~

#### Install cron for incremental backup

Edit root crontab

~~~
crontab -e
~~~

Add this ligne

~~~
30 10 * * * /usr/sbin/bkctld inc && /usr/sbin/bkctld rm
~~~ 

> **Notes :**
> If you want mutiples backups in a day (1 by hour maximum) you can run `bkctld inc` multiples times
> If you want keep incremental backup **for ever**, you just need don't run `bkctld rm`

## Usage

~~~
man bkctld
~~~

#### Client configuration

You can save various systems on evobackup jail :  Linux, BSD, Windows, MacOSX. Only prequisites is rsync command.

~~~
rsync -av -e "ssh -p SSH_PORT" /home/ root@SERVER_NAME:/var/backup/home/
~~~

An example script is present in docs/zzz_evobackup, clone evobackup repo and read **CLIENT CONFIGURATION** section of the manual.

~~~
git clone https://forge.evolix.org/evobackup.git
cd evobackup
man ./docs/bkctld.8
~~~
