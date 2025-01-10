EvoBackup
=========

EvoBackup is a combination of tools to manage backups on Evolix servers.

## The client side

_What you install on the servers you want to backup._

There is a backup script (usually executed by cron or similar), a utility script and some libraries.

More information in the [client README](/evolix/evobackup/src/branch/master/client/README.md).

## The server side

_What you install on the servers that store the backups._

This is also known as `bkctld` : a program to manage SSH servers in chroots to isolate backup destinations, daily copies and data retention.

More information in the [server README](/evolix/evobackup/src/branch/master/server/README.md).
