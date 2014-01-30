#!/bin/bash

# Handle removing of incrementals.

. /etc/evobackup/conf.d/incrementals.cf

tmpdir=$(mktemp --tmpdir=/tmp -d evobackup.tmpdir.XXX)
emptydir=$(mktemp --tmpdir=/tmp -d evobackup.empty.XXX)
tmplog=$(mktemp --tmpdir=/tmp evobackup.tmplog.XXX)
# Don't return *, if bash glob don't find files/dir.
shopt -s nullglob

# For each client, delete needed incrementals.
for client in ${CONFDIR}/*; do
        # Get only the name of the backup.
        backupname=${client#${CONFDIR}/}
        # List actual incrementals backup.
        for inc in ${INCDIR}/${backupname}/*; do
                echo $inc
        done > ${tmpdir}/${backupname}.files
        # List non-obsolete incrementals backup.
        for incConf in $(cat ${CONFDIR}/${backupname}); do
                MYDATE=$(echo $incConf | cut -d. -f1)
                BEFORE=$(echo $incConf | cut -d. -f2)
                date -d "$(date $MYDATE) $BEFORE" "+%Y-%m-%d"
        done  > ${tmpdir}/${backupname}.keep
        # Delete obsolete incrementals backup
        for inc in $(grep -v -f ${tmpdir}/${backupname}.keep ${tmpdir}/${backupname}.files); do
            start=$(date --rfc-3339=seconds)
            echo "Deletion of ${backupname}/${inc#${INCDIR}/${backupname}/} started at ${start}." >> $tmplog
            # We use rsync to delete since it is faster than rm!
            rsync -a --delete ${emptydir}/ $inc
            rm -r $inc
            rm -r $emptydir
            stop=$(date --rfc-3339=seconds)
            echo "Deletion of ${backupname}/${inc#${INCDIR}/${backupname}/} ended at ${stop}." >> $tmplog
        done
done
# Save tmplog to global log.
cat $tmplog >> $LOGFILE
# Send mail report.
< $tmplog mailx -s mail -s "[info] EvoBackup - deletion of obsolete incrementals" $MAIL_TO
# Cleaning
rm -rf $tmpdir
rm $tmplog