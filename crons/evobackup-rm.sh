#!/bin/bash

# Handle removing of incrementals.

. /etc/evobackup/conf.d/incrementals.cf

tmpdir=$(mktemp --tmpdir=/tmp -d evobackup.tmpdir.XXX)
emptydir=$(mktemp --tmpdir=/tmp -d evobackup.empty.XXX)
tmplog=$(mktemp --tmpdir=/tmp evobackup.tmplog.XXX)
# Don't return *, if bash glob don't find files/dir.
shopt -s nullglob

# For each client (machine to backup), delete old incrementals according to the
# config file.
for client in ${CONFDIR}/*; do
    # Get only the name of the backup.
    backupname=${client#${CONFDIR}/}
    # List actual incrementals backup.
    for inc in ${INCDIR}/${backupname}/*; do
        echo $inc
    done > ${tmpdir}/${backupname}.files
    # List non-obsolete incrementals backup.
    for incConf in $(cat ${CONFDIR}/${backupname}); do
        mydate=$(echo $incConf | cut -d. -f1)
        before=$(echo $incConf | cut -d. -f2)
        date -d "$(date $mydate) $before" "+%Y-%m-%d"
    done > ${tmpdir}/${backupname}.keep
    # Delete obsolete incrementals backup
    for inc in $(grep -v -f ${tmpdir}/${backupname}.keep ${tmpdir}/${backupname}.files); do
        start=$(date --rfc-3339=seconds)
        echo "Deletion of ${backupname}/${inc#${INCDIR}/${backupname}/} started at ${start}." >> $tmplog
        # We use rsync to delete since it is faster than rm!
        rsync -a --delete ${emptydir}/ $inc
        rmdir $inc
        stop=$(date --rfc-3339=seconds)
        echo "Deletion of ${backupname}/${inc#${INCDIR}/${backupname}/} ended at ${stop}." >> $tmplog
    done
done

# Send mail report only if incrementals where deleted.
if [ -s $tmplog ]; then
    # Save tmplog to global log & send mail.
    cat $tmplog >> $LOGFILE
    < $tmplog mailx -s "[info] EvoBackup - deletion of obsolete incrementals" $MAIL_TO
fi
# Cleaning
rm -rf $tmpdir $emptydir $tmplog