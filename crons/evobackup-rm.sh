#!/bin/sh

# Handle removing of incrementals.

. /etc/evobackup/conf.d/incrementals.cf

tmpdir=$(mktemp --tmpdir=/tmp -d evobackup.XXX)
emptydir=$(mktemp --tmpdir=/tmp -d evobackup.XXX)

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
            echo -n "Delete of ${backupname}/${inc#${INCDIR}/${backupname}/} started at ${start}." >> $LOGFILE
            # We use rsync to delete since it is faster than rm!
            rsync -a --delete ${emptydir}/ $inc
            rm -r $inc
            rm -r $emptydir
            stop=$(date --rfc-3339=seconds)
            echo -n "Delete of ${backupname}/${inc#${INCDIR}/${backupname}/} ended at ${stop}." >> $LOGFILE
        done
done | tee -a $LOGFILE | mail -s "[info] EvoBackup - purge incs" $MAIL_TO

# Cleaning
rm -rf $tmpdir