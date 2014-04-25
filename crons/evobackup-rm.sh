#!/bin/bash

# Handle removing of incrementals.

. /etc/evobackup/conf.d/cron.cf

tmpdir=$(mktemp --tmpdir=/tmp -d evobackup.tmpdir.XXX)
emptydir=$(mktemp --tmpdir=/tmp -d evobackup.empty.XXX)
tmplog=$(mktemp --tmpdir=/tmp evobackup.tmplog.XXX)
dst="rsync://${RSYNC_USERNAME}@${BACKUPSERVER}/${RSYNC_PATH}"


# List actual incrementals backup.
listincs=$(rsync --list-only ${dst} |
    sed -E 's#^([^\s]+\s+){4}##' | sed -e '/\./d' -e '/current/d' | tr -s '\n' ' '
)
for inc in $listincs; do
    echo $inc >> ${tmpdir}/incs.files
done
# List non-obsolete incrementals backup.
for incConf in $(cat ${CONFDIR}/incs.cf); do
    mydate=$(echo $incConf | cut -d. -f1)
    before=$(echo $incConf | cut -d. -f2)
    date -d "$(date $mydate) $before" "+%Y-%m-%d"
done > ${tmpdir}/incs.keep
# Delete obsolete incrementals backup
for inc in $(grep -v -f ${tmpdir}/incs.keep ${tmpdir}/incs.files); do
    start=$(date --rfc-3339=seconds)
    echo "Deletion of $inc started at ${start}." >> $tmplog
    rsync -a --delete ${emptydir}/ ${dst}/${inc}
    sleep 5
    rsync -a --delete --include="${inc}" --exclude="*" ${emptydir}/ $dst 
    stop=$(date --rfc-3339=seconds)
    echo "Deletion of $inc ended at ${stop}." >> $tmplog
done

# Send mail report only if incrementals where deleted.
if [ -s $tmplog ]; then
    # Save tmplog to global log & send mail.
    cat $tmplog >> $LOG
    < $tmplog mailx -s "[info] EvoBackup - deletion of obsolete incrementals" $MAIL_TO
fi
# Cleaning
rm -rf $tmpdir $emptydir $tmplog
