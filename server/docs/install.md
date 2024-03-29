# Install

## Install from package

The install documentation is [here](https://intra.evolix.net/OutilsInternes/bkctld)

## Instal from sources

Warning: `cp`-ing the files without `-n` or `-i` will replace existing files !

~~~
# git clone https://gitea.evolix.org/evolix/evobackup.git
# cd evobackup
# cp server/bkctld /usr/local/sbin/
# mkdir -p /usr/local/lib/bkctld
# cp server/lib/* /usr/local/lib/bkctld/
# mkdir -p /usr/local/share/bkctld
# cp server/tpl/* /usr/local/share/bkctld/
# cp server/bkctld.service /lib/systemd/system/
# mkdir -p /usr/local/share/doc/bkctld
# cp client/zzz_evobackup /usr/local/share/doc/bkctld/
# mkdir -p /usr/local/share/bash_completion/
# cp server/bash_completion /usr/local/share/bash_completion/bkctld
# cp server/bkctld.conf /etc/default/bkctld
~~~

## Chroot dependencies

The chroot jails depend on these packages

~~~
apt install \
    bash \
    coreutils \
    sed \
    dash \
    mount \
    rsync \
    openssh-server \
    openssh-sftp-server \
    libc6-i386 \
    libc6
~~~

## Client dependencies

The clients only require OpenSSH and Rsync.

### Cron job for incremental backups

Edit the root crontab

~~~
# $editor /etc/cron.d/bkctld
+ MAILTO=alert4@evolix.net
+ 30 11 * * * root /usr/sbin/bkctld inc && /usr/sbin/bkctld rm
+ 30 23 * * * root /usr/share/scripts/check-incs.sh 1> /dev/null
~~~

## Notes
If you want mutiples backups in a day (1 per hour maximum) you can
run `bkctld inc` multiples times, if you want to keep incremental
backups **for ever**, just don't run `bkctld rm`.
