# Install

A Debian package is available in the Evolix repository

~~~
echo "http://pub.evolix.net/jessie/" >> /etc/apt/sources.list
apt update
apt install bkctld
~~~

Then edit `/etc//bkctld`

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

The clients only require OpenSSH and rsync.

### Cron job for incremental backups

Edit the root crontab

~~~
# crontab -e
+ 30 10 * * * /usr/sbin/bkctld inc && /usr/sbin/bkctld rm
~~~

## Notes
If you want mutiples backups in a day (1 by hour maximum) you can
run `bkctld inc` multiples times, if you want to keep incremental
backups **for ever**, just don't run `bkctld rm`.