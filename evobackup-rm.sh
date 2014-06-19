#!/bin/sh

# Script backups incrementaux
# Evolix (c) 2007

CONFDIR=/etc/evobackup/
DATE=$(date +"%Y-%m-%d")
LOGFILE=/var/log/evobackup-sync.log
JAILDIR=/backup/jails/
INCDIR=/backup/incs/
MYMAIL=jdoe@example.com

TMPDIR=$(mktemp --tmpdir=/tmp -d evobackup.tmpdir.XXX)
EMPTYDIR=$(mktemp --tmpdir=/tmp -d evobackup.empty.XXX)

for i in $( ls -1 $CONFDIR ); do

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
        [ -n "$j" ] && rsync -a --delete $EMPTYDIR/ $j*
        [ -n "$j" ] && rmdir $j* && touch /tmp/evobackup-rm.txt
        echo -n "Delete $i/$j ends at : " >> $LOGFILE
        /bin/date +"%d-%m-%Y ; %H:%M" >> $LOGFILE
        done
done | tee -a $LOGFILE | ( [ -e "/tmp/evobackup-rm.txt" ] && mail -s "[info] EvoBackup - purge incs" $MYMAIL && rm /tmp/evobackup-rm.txt )

rm -rf $TMPDIR $EMPTYDIR
