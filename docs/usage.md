# NAME

bkctld - tool to manage evobackup jail

# SYNOPSIS

~~~
bkctld <command> [<args>]
~~~

# DESCRIPTION

bkctld is a shell script that creates and manages a backup server
which can handle the backups of many other servers (clients).
It uses OPENSSH and chroot's to sandbox every client's backups.
Each client will upload it's data every day using rsync in it's chroot
(using the root account).

Prior backups are stored incrementally outside of the chroot
using hard links or BTRFS snapshots (So they can not be affected
by the client). Which backups are kept over time can be configured in the jail's nominal [incl.tpl](incrementals.md) configuration file. A large enough volume must be mounted on `/backup`, if the filesystem is formatted 
with BTRFS, bkctld will use sub-volumes and snapshots to save space.

It's default settings can be overridden in the [configuration file](configuration.md).

# BKCTLD COMMANDS

Create an evobackup jail :

~~~
bkctld init <jailname>
~~~

Update an evobackup jail or all :

~~~
bkctld update <jailname>|all
~~~

Remove an evobackup jail or all :

~~~
bkctld remove <jailname>|all
~~~

Start an evobackup jail or all :

~~~
bkctld start <jailname>|all
~~~

Stop an evobackup jail or all :

~~~
bkctld stop <jailname>|all
~~~

Reload an evobackup jail or all :

~~~
bkctld reload <jailname>|all
~~~
        
Restart an evobackup jail or all :

~~~
bkctld restart <jailname>|all
~~~

Sync an evobackup jail or all.
Second server is defined by $NODE var in /etc/default/bkctld :

~~~
bkctld sync <jailname>|all
~~~

Print status of all evobackup jail or one jail :

~~~
bkctld status [<jailname>]
~~~

Print or set the SSH public key of an evobackup jail :

~~~
bkctld key <jailname> [<keyfile>]
~~~

Print or set the SSH port of an evobackup jail.
Auto to set next available port (last + 1) :

~~~
bkctld port <jailname> [<ssh_port>|auto]
~~~

Print or set allowed IP of an evobackup jail.
All for unrestricted access (default) :

~~~
bkctld ip <jailname> [<ip>|all]
~~~

Generate inc of an evobackup jail :

~~~
bkctld inc
~~~

Remove old inc of an evobackup jail :

~~~
bkctld rm
~~~

# CLIENT CONFIGURATION
Before creating a jail and backing up a client,
the backup server administrator will need:

* The host name of the client system.
* The public RSA OpenSSH key for the root user of the client system,
it is recommended the private key be password-less if automation is desired.
* The IPv4 address of the client system is needed
if the administrator wishes to maintain a whitelist,
see the FIREWALL_RULES variable in [bkctld.conf](configuration.md)

He can then create the jail:

```
# bkctld init CLIENT_HOST_NAME
# bkctld key CLIENT_HOST_NAME /root/CLIENT_HOST_NAME.pub
# bkctld ip CLIENT_HOST_NAME CLIENT_IP_ADDRESS
# bkctld start CLIENT_HOST_NAME
# bkctld status CLIENT_HOST_NAME
```

And override the default [incremental](incrementals.md) rules

```
# $EDITOR /etc/evobackup/CLIENT_HOST_NAME
```

To sync itself, the client server will need to install rsync.
It can then be run manually:

```
# rsync -av -e "ssh -p JAIL_PORT" /home/ root@BACKUP_SERVER:/var/backup/home/
```

If a more automated setup is required,
a script can be written in any programming language. In this case,
it may be useful to validate the backup server's identity before hand.

```
# ssh -p JAIL_PORT BACKUP_SERVER
```

A bash example to be run under the root user's crontab
can be found in the  [source repository](https://gitea.evolix.org/evolix/evobackup/src/branch/master/zzz_evobackup)

# SEE ALSO

rsync(1), sshd(8), chroot(8).
