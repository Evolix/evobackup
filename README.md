Bkctld (aka server-side evobackup)
=========

bkctld helps you manage the receiving side of a backup infrastructure.
It is licensed under the AGPLv3.

With bkctld you create and manage "jails". They contain a chrooted and dedicated SSH server, with it's own TCP port and optionnaly it's own set of iptables rules.

With bkctld you can have hundreds of jails, one for each client to push its data (using Rsync/SFTP). Each client can only see its own data.

In addition to the traditional "ext4" filesystem, bkctld also supports the btrfs filesystem and manages subvolumes automatically.

With bkctld you can create "timestamped" copies of the data, to keep different versions of the same data at different points in time. If the filesystem is btrfs, it creates subvolumes snapshots, otherwise it creates copies with hard-links (for file-level deduplication).

With btrfs you can have a data retention policy to automatically destroy timestamped copies of your data. For example, keep a copy for the last 5 days and the first day of the last 3 months.

~~~
                                    Backup server
                                    ************
Client 1 ------ SSH/Rsync ------->  * tcp/2222 *
                                    ************
Client 2 ------ SSH/Rsync ------->  * tcp/2223 *
                                    ************
~~~

This method uses standard tools (ssh, rsync, cp -al, btrfs subvolume) and has been used for many years by Evolix to backup hundreds of servers, totaling many terabytes of data, each day. bkctld has been tested on Debian Jessie (8), Stretch (9) and Buster (10) and should be compatible with other Debian versions or derived distributions like Ubuntu.

A large enough volume must be mounted on `/backup`, we recommend the usage of **BTRFS** so you can use sub-volumes and snapshots.
This volume can also be encrypted with **LUKS**.

## Security considerations

The client obviously has access to its uploaded data (in the chroot), but the timestamped copies are outside the chroot, to reduce the risk or complete backup erasure from a compromised client.

Since the client connects to the backup server with root, it can mess with the jail and destroy the data. But the timestamped copies are out of reach because outside of the chroot.

It means that **if the client server is compromised**, an attacker can destroy the latest copy of the backed up data, but not the timestamped copies.
And **if the backup server is compromised** an attacker has complete access to all the backup data (inside and outside the jails), but they don't have any access to the client.

This architecture is as secure as SSH, Rsync, chroot and iptables are.

## Install

See the [installation guide](docs/install.md) for instructions.

## Testing

You can deploy test environments with Vagrant :

~~~
vagrant up
~~~

### Deployment

Run `vagrant rsync-auto` in a terminal for automatic synchronization of
your local code with Vagrant VM :

~~~
vagrant rsync-auto
~~~

### Bats

You can run [bats](https://github.com/sstephenson/bats) tests with
the *test* provisioner :

~~~
vagrant provision --provision-with test
~~~

You can also run the tests from inside the VM

~~~
localhost $ vagrant ssh buster-btrfs
vagrant@buster-btrfs $ sudo -i
root@buster-btrfs # bats /vagrant/test/*.bats
~~~

You should shellcheck your bats files, but with shellcheck > 0.4.6, because the 0.4.0 version doesn't support bats syntax.

## Usage

See [docs/usage.md](docs/usage.md).

The man(1) page, in troff(7) language, can be generated with pandoc:

~~~
pandoc -f markdown \
	-t man usage.md \
	--template default.man \
	-V title=bkctld \
	-V section=8 \
	-V date="$(date '+%d %b %Y')" \
	-V footer="$(git describe --tags)" \
	-V header="bkctld man page"
~~~

#### Client configuration

You can backup various systems in the evobackup jails : Linux, BSD,
Windows, macOS. The only need Rsync or an SFTP client.

~~~
rsync -av -e "ssh -p SSH_PORT" /home/ root@SERVER_NAME:/var/backup/home/
~~~

An example synchronization script is present in `zzz_evobackup`,
clone the evobackup repository and read the **CLIENT CONFIGURATION**
section of the manual.

~~~
git clone https://gitea.evolix.org/evolix/evobackup.git
cd evobackup
man ./docs/bkctld.8
~~~
