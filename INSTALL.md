Installing EvoBackup
====================

Backup server side
------------------

1) Git clone the project (i.e in /root/evobackup).

2) Install configuration files.

```
root@backupserver:~/evobackup# install.sh
```

This will create /etc/evobackup and /etc/init.d/evobackup (or
/etc/init/evobackup.conf for Ubuntu).

3) Set up the first chroot.

```
root@backupserver:~/evobackup# chroot-new.sh -n client1 -i 192.168.0.10 -p 2222 -k /path/to/rsakeyclient1.pub
```

This will create the OpenSSH chroot for the machine "client1", listening on
port 2222 and accepting only connections from 192.168.0.10 using public key
rsakeyclient1.pub.

Tip: If you have already a chroot, you can commit the port option (-p), it
will be incremented from the last chroot.

4) Handle incrementals by modifying /etc/evobackup/conf.d/incs/client1

Syntax of this file is simple:

* +%Y-%m-%d.-0day Keep actual day
* +%Y-%m-%d.-1day Keep yesterday
* +%Y-%m-01.-0month Keep the firt day of the actual month
* +%Y-%m-01.-1month Keep the first day of the last month

Tip: You can use rdiff-backup in place of rsync, and choose to not use
EvoBackup incrementals method. You need to modify the cronjob.

5) Set up the scripts which will handle incrementals.

```
root@backupserver:~/evobackup# mkdir -p /usr/share/scripts
root@backupserver:~/evobackup# cp crons/evobackup-{inc,rm}.sh /usr/share/scripts/
root@backupserver:~/evobackup# chmod u+x /usr/share/scripts/evobackup-{inc,rm}.sh
root@backupserver:~/evobackup# crontab -e
```

Set this in the root crontab

```
29 10 * * * pkill evobackup-rm.sh && echo "Kill evobackup-rm.sh done" | mail -s "[warn] EvoBackup - purge incs interrupted" root
30 10 * * * /usr/share/scripts/evobackup-inc.sh && /usr/share/scripts/evobackup-rm.sh
````

Client side
-----------

1) Git clone the project (i.e in /root/evobackup).

2) Generates OpenSSH key for user root (if user root don't have one already).

```
root@client1:~/evobackup# ssh-keygen
```

Do not set a passphrase, otherwise you will need to enter the passphrase (or
store it using an agent) for each backups!

3) Install configuration files.

```
root@client1:~/evobackup# install.sh client
```

4) Add the zzz_evobackup crontab into the daily cronjobs (recommended):

```
root@client1:~/evobackup# cp crons/zzz_evobackup /etc/cron.daily/
root@client1:~/evobackup# chmod 700 /etc/cron.daily/zzz_evobackup
```

Why "zzz"? Because we want the backup cronjob to be the last one.

5) Configure the cronjob.

In /etc/evobackup:

* What to backup using shell scripts in actions.d. By default all scripts are
  commented out. Un-comment or write your own code, this will be launched
  before the rsync, using run-parts.

* What to include in conf.d/include.cf
* What to exclude in conf.d/exclude.cf
* General config in conf.d/cron.cf

6) Optional, test with sh -x.

```
root@client1:~/evobackup# sh -x /etc/cron.daily/zzz_evobackup
```

Updating OpenSSH chroot
-----------------------

When you upgrade you system you may need to upgrade the OpenSSH chroot. To do
that launch update-chroot.sh.

```
root@backupserver:~/evobackup# chroot-update.sh
```

Then reload sshd daemons.