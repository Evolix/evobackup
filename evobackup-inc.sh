#!/bin/sh

# Script backups incrementaux
# Evolix (c) 2007

CONFDIR=/etc/evobackup/
DATE=$(date +"%d-%m-%Y")
LOGFILE=/var/log/evobackup-sync.log
TMPDIR=/tmp/evobackup/
JAILDIR=/backup/jails/
INCDIR=/backup/incs/
MYMAIL=jdoe@example.com

mkdir -p $TMPDIR

for i in $( ls $CONFDIR ); do

        mkdir -p "$INCDIR"$i

        # hard copy everyday
        cp -alx $JAILDIR$i $INCDIR$i/$DATE

        # list actual inc backups
        for j in $( ls $INCDIR$i ); do
                echo $j
        done > "$TMPDIR"$i.files

        # list non-obsolete inc backups
        for j in $( cat $CONFDIR$i ); do
                MYDATE=$( echo $j | cut -d. -f1 )
                BEFORE=$( echo $j | cut -d. -f2 )
                date -d "$(date $MYDATE) $BEFORE" "+%d-%m-%Y"
        done  > "$TMPDIR"$i.keep

        # delete obsolete inc backups
        for j in $( grep -v -f "$TMPDIR"$i.keep "$TMPDIR"$i.files ); do
                echo "Suppression du backup $j ($i)"
                cd $INCDIR$i
                rm -rf $j
        done

done | tee -a $LOGFILE | mail -s "[info] EvoBackup - incrementaux" $MYMAIL

