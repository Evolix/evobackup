#!/bin/sh

# Script backups incrementaux
# Evolix (c) 2007

CONFDIR=/etc/evobackup/
DATE=$(date +"%Y-%m-%d-%H")
LOGFILE=/var/log/evobackup-incs.log
JAILDIR=/backup/jails/
INCDIR=/backup/incs/
MYMAIL=jdoe@example.com

for i in $( ls -1 $CONFDIR ); do

    # hard copy everyday
    echo -n "hard copy $i begins at : " >> $LOGFILE
    /bin/date +"%d-%m-%Y ; %H:%M" >> $LOGFILE
    mkdir -p "$INCDIR"$i
    cp -alx $JAILDIR$i $INCDIR$i/$DATE
    echo -n "hard copy $i ends at : " >> $LOGFILE
    /bin/date +"%d-%m-%Y ; %H:%M" >> $LOGFILE

done | tee -a $LOGFILE | mail -s "[info] EvoBackup - create incs" $MYMAIL

