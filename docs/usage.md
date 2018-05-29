# NAME

bkctld - tool to manage evobackup jail

# SYNOPSIS

~~~
bkctld <command> [<args>]
~~~

# DESCRIPTION

bkctld is a shell script used to set up and manage a backup server able to receive data from many servers (clients).

The aim is to run a SSH chroot environment (called "jails" in the FreeBSD world) for every single client. The client will then be able to send data over SSH using rsync in his own chroot environment (using root account).

Incrementals are stored outside the chroot using hard links or btrfs snapshots (thus incrementals are not accessible by clients). This method has the advantage to keep incrementals securely isolated using low space on device.

A suitable volume size must be mounted on /backup (usage of **btrfs** is preferable, providing subvolume and snapshot fonctionnality). For security reason, you can use an encrypted volume (e.g. **luks**)

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

# CONFIGURATION VARS

bkctld configuration has to be set in /etc/default/bkctld file.

## REQUIREDS VARS

Default required vars are defined in bkctld script. Alter them to override default values.

* CONFDIR (default: /etc/evobackup) : Dir where incremental backup is configured. See INCS CONFIGURATION section for details.
* JAILDIR (default : /backup/jails) : Dir for jail's root dir. BTRFS recommended.
* INCDIR (default : /backups/incs) : Dir where incremental backup is stored. BTRFS recommended.
* TPLDIR (default : /usr/share/bkctld) : Dir where jail template file is stored.
* LOCALTPLDIR (default : /usr/local/share/bkctld) : Dir for surcharge jail templates.
* LOGLEVEL (default : 6) : Define loglevel, based on syslog severity level.

## OPTIONALS VARS

Optionnals vars are no default value. No set them desactivate correspondant fonctionnality.

* FIREWALL_RULES (default: no firewall auto configuration) : Configuration file were firewall was configured to allow jail access. This file must be sourced by your firewall configuration tool.

# INCS CONFIGURATION

Incremental backups was configured in $CONFDIR/<jailname>. Some example of syntax. 

Keep the incrememtal backup of today :

~~~
+%Y-%m-%d.-0day
~~~

Keep the incremental backup of yesterday :

~~~
+%Y-%m-%d.-1day
~~~

Keep the incremental backup of the first day of this month :

~~~
+%Y-%m-01.-0month
~~~

Keep the incremental backup of the first day of last month :

~~~
+%Y-%m-01.-1month
~~~

Keep the incremental backup of every 15 days :

~~~
+%Y-%m-01.-1month
+%Y-%m-15.-1month
~~~

Keep the incremental backup of the first january :

~~~
+%Y-01-01.-1month
~~~

Default value : keep incremental of last 4 days and last 2 months. Change default in $LOCALTPLDIR/inc.tpl :

~~~
+%Y-%m-%d.-0day
+%Y-%m-%d.-1day
+%Y-%m-%d.-2day
+%Y-%m-%d.-3day
+%Y-%m-01.-0month
+%Y-%m-01.-1month
~~~

# CLIENT CONFIGURATION

You can save various systems on evobackup jail :  Linux, BSD, Windows, MacOSX. Only prequisites is rsync command.

~~~
rsync -av -e "ssh -p SSH_PORT" /home/ root@SERVER_NAME:/var/backup/home/
~~~

You  can  simply create a shell script which use rsync for backup your's servers. An example script is available in zzz_evobackup for quickstart.

This documentation explain how to use this example script.

Install example script in crontab :

~~~
# For Linux
install -v -m700 zzz_evobackup /etc/cron.daily/

# For FreeBSD
install -v -m700 zzz_evobackup /etc/periodic/daily/
~~~

Generate an SSH key for root account with no passphrase :

~~~
ssh-keygen
~~~

Sent /root/.ssh/id_rsa.pub to backup server administrator or read BKCTLD COMMANDS section.

Edit zzz_evobackup script and update this variables :

* SSH_PORT : Port of corespondant evobackup jail.
* MAIL : Email address for notification.
* NODE : Use for alternate between mutiple backup servers. Default value permit to save on node0 on pair day and on node1 on impair day.
* SRV : Adress of your backup serveur.

Uncomment service dump, ex Mysql / LDAP / PostgreQL / ...

Itiniate SSH connection and validate fingerprint :

~~~
ssh -p SSH_PORT SERVER_NAME
~~~

Your daily evobackup is in place !

# SEE ALSO

rsync(1), sshd(8), chroot(8).
