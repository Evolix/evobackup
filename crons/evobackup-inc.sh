#!/bin/sh
# Handles creating incrementals backup.

. /etc/evobackup/conf.d/incrementals.cf

start=$(date --rfc-3339=seconds)

for client in ${CONFDIR}/*; do
    backupname=${client#/etc/evobackup/conf.d/incs/}
    # hard copy everyday
    echo -n "Hard copy of backup $backupname started at $start. " \
        >> $LOGFILE
    [[ ! -d ${INCDIR}/${backupname} ]] && mkdir -p ${INCDIR}/${backupname}
    cp -alx ${JAILDIR}/${backupname} ${INCDIR}/${backupname}/${DATEDIR}
    stop=$(date --rfc-3339=seconds)
    echo -n "Hard copy of $backupname ended at $stop." >> $LOGFILE
done | tee -a $LOGFILE | mailx -s "[info] EvoBackup report of creating incrementals" $MAIL_TO