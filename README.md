EvoBackup-linkdest
=========

(Fork of EvoBackup using rsync --link-dest as incrementals).

EvoBackup is a bunch of shell scripts to backup a machine to a rsync server.
Licence is GPLv2.

This method uses standard tools (ssh, rsync). EvoBackup is used for
many years by Evolix for back up each day hundreds of servers which uses many
terabytes of data.

Backup server
-------------

The backup server need to use rsync. Evobackup-linkdest was tested only on
Online backup offer using rsync and RPN.

Needed packages:

* rsync
* bsd-mailx (or other package providing /usr/bin/mailx)

Main directories:

* /etc/evobackup: Config dir

To install and configure EvoBackup read INSTALL.md