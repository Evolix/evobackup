Installing EvoBackup
====================

Backup server side
------------------

A rsync daemon launched in server mode.


Client side
-----------

1) Git clone the project (i.e in /root/evobackup).

2) Install configuration files.

```
root@client1:~/evobackup# install.sh client
```

3) Add the zzz_evobackup crontab into the daily cronjobs (recommended):

```
root@client1:~/evobackup# cp crons/zzz_evobackup /etc/cron.daily/
root@client1:~/evobackup# chmod 700 /etc/cron.daily/zzz_evobackup
```

Why "zzz"? Because we want the backup cronjob to be the last one.

4) Configure the cronjob.

In /etc/evobackup:

* What to backup using shell scripts in actions.d. By default all scripts are
  disabled. To enable a script, move it by clearing .disabled part.
  You can also adapt these scripts or write your own.
  This will be launched before the rsync, using run-parts.

* What to backup using rsync filter rules in conf.d/include.cf
* Incrementals to keep in conf.d/incs.cf
* General config in conf.d/cron.cf

5) Optional, test with ```sh -x &```, and see if it seems to works.

```
root@client1:~/evobackup# sh -x /etc/cron.daily/zzz_evobackup &
root@client1:~/evobackup# tail -f /tmp/evobackup.*
```

If it works, you can wait for it to finish or cancel it.

```
root@client1:~/evobackup# ^C
root@client1:~/evobackup# fg
root@client1:~/evobackup# ^C
```