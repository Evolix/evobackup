#!/bin/sh
# Handles creating incrementals backup.

. /etc/evobackup/conf.d/incrementals.cf

tmplog=$(mktemp --tmpdir=/tmp evobackup.tmplog.XXX)
# Don't return *, if bash glob don't find files/dir.
shopt -s nullglob

# Search for incrementals to do.
for client in ${CONFDIR}/*; do
    start=$(date --rfc-3339=seconds)
    backupname=${client#/etc/evobackup/conf.d/incs/}
    echo "Incrementals of $backupname started at $start. " \
        >> $tmplog
    [[ ! -d ${INCDIR}/${backupname} ]] && mkdir -p ${INCDIR}/${backupname}
    # Do the incrementals.
    cp -alx ${JAILDIR}/${backupname} ${INCDIR}/${backupname}/${DATEDIR}
    stop=$(date --rfc-3339=seconds)
    echo "Incrementals of $backupname ended at $stop." >> $tmplog
done
# Save tmplog to global log.
cat $tmplog >> $LOGFILE
# Send mail report.
< $tmplog mailx -s "[info] EvoBackup report of creating incrementals" $MAIL_TO
# Cleaning.
rm $tmplog