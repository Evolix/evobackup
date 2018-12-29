Bkctld (aka evobackup)
=========

Bkctld is a shell script that creates and manages a backup server
which can handle the backups of many other servers (clients). It
is licensed under the AGPLv3.

It uses SSH chroots (called "jails" in the FreeBSD world) to sandbox
every clients backups. Each client will upload it's data every day
using rsync in it's chroot (using the root account).  Prior backups
are stored incrementally outside of the chroot using hard links or
BTRFS snapshots.  (So they can not be affected by the client). 

Using this method, we can keep a large quantity of backups of each
client securely and efficiently.

~~~
                                    Backup server
                                    ************
Server 1 ------ SSH/rsync ------->  * tcp/2222 *
                                    *          *
Server 2 ------ SSH/rsync ------->  * tcp/2223 *
                                    ************
~~~

This method uses standard tools (ssh, rsync, cp -al, btrfs subvolume)
and has been used for many years by Evolix to backup hundreds of
servers, totaling many terabytes of data, each day.  bkctld has
been tested on Debian Jessie and should be compatible with other
Debian versions or derived distributions like Ubuntu.

A large enough volume must be mounted on `/backup`, we recommend
the usage of **BTRFS** so you can use sub-volumes and snapshots.
This volume can also be encrypted with **LUKS**.

## Install

See the [installation guide](docs/install.md) for instructions.

## Testing

You can deploy test environments with Vagrant :

~~~
vagrant up
~~~

### Deployment

Launch rsync-auto in a terminal for automatic synchronization of
your local code with Vagrant VM :

~~~
vagrant rsync-auto
~~~

### Bats

You can run [bats](https://github.com/sstephenson/bats) tests with
the *test* provision :

~~~
vagrant provision --provision-with test
~~~

## Usage

See [docs/usage.md](docs/usage.md) or bkctld(8)

#### Client configuration

You can save various systems in the evobackup jails :  Linux, BSD,
Windows, MacOSX. The only prerequisite is the rsync command.

~~~
rsync -av -e "ssh -p SSH_PORT" /home/ root@SERVER_NAME:/var/backup/home/
~~~

An example synchronization script is present in `zzz_evobackup`,
clone the evobackup repository and read the **CLIENT CONFIGURATION**
section of the manual.

~~~
git clone https://forge.evolix.org/evobackup.git
cd evobackup
man ./docs/bkctld.8
~~~
