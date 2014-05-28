#!/bin/sh

# Script backups incrementaux
# Evolix (c) 2007

CONFDIR=/etc/evobackup/
DATE=$(date +"%Y-%m-%d")
LOGFILE=/var/log/evobackup-sync.log
TMPDIR=/tmp/evobackup/
JAILDIR=/backup/jails/
INCDIR=/backup/incs/
MYMAIL=jdoe@example.com

mkdir -p $TMPDIR

for i in $( ls $CONFDIR ); do

        # list actual inc backups
        for j in $( ls $INCDIR$i ); do
                echo $j
        done > "$TMPDIR"$i.files

        # list non-obsolete inc backups
        for j in $( cat $CONFDIR$i ); do
                MYDATE=$( echo $j | cut -d. -f1 )
                BEFORE=$( echo $j | cut -d. -f2 )
                date -d "$(date $MYDATE) $BEFORE" "+%Y-%m-%d"
        done  > "$TMPDIR"$i.keep

        # delete obsolete inc backups
        for j in $( grep -v -f "$TMPDIR"$i.keep "$TMPDIR"$i.files ); do
        echo -n "Delete $i/$j begins at : " >> $LOGFILE
        /bin/date +"%d-%m-%Y ; %H:%M" >> $LOGFILE
                cd $INCDIR$i
                [ -n "$j" ] && rm -rf $j*
        echo -n "Delete $i/$j ends at : " >> $LOGFILE
        /bin/date +"%d-%m-%Y ; %H:%M" >> $LOGFILE
        done

done | tee -a $LOGFILE | mail -s "[info] EvoBackup - purge incs" $MYMAIL

