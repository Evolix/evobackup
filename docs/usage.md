BKCTLD(8) - System Manager's Manual

# NAME

**bkctld** - tool to manage evobackup jails

# SYNOPSIS

**bkctld**
\[*operand...*]

# DESCRIPTION

**bkctld**
is a shell script that creates and manages a backup server
which can handle the backups of many other servers (clients).

It uses
ssh(1)
and
chroot(8)
to sandbox every client's backups.
Each client will upload it's data every day
using
rsync(1)
in it's
chroot(8)
(using the root account).

Prior backups are stored incrementally outside of the
chroot(8)
using
ln(1)
hard links or BTRFS snapshots.
(So they can not be affected by the client),
which backups are kept over time can be configured in the jail's nominal
evobackup-incl(5)
configuration file.

A large enough volume must be mounted on
*/backup*,
if the filesystem is formatted with BTRFS,
**bkctld**
will use sub-volumes and snapshots to save space.

It's default settings can be overridden in
bkctld.conf(5)
file.

The following operands are available:

**init** *jailname*

> Create an evobackup jail

**update** **all** | *jailname*

> Update an evobackup jail

**remove** **all** | *jailname*

> Remove an evobackup jail

**start** **all** | *jailname*

> Start an evobackup jail

**stop** **all** | *jailname*

> Stop an evobackup jail

**reload** **all** | *jailname*

> Reload an evobackup jail

**restart** **all** | *jailname*

> Restart an evobackup jail

**sync** **all** | *jailname*

> Sync an evobackup jail, the mirror server is defined by the
> `$NODE`
> variable in
> */etc/default/bkctld*

**status** \[*jailname*]

> Print the status of all jails or only
> \[*jailname*].

**key** *jailname* \[*keyfile*]

> Print or set the
> ssh(1)
> public key of an evobackup jail

**port** *jailname* \[**auto** | *port*]

> Print or set the
> ssh(1)
> \[*port*]
> of an evobackup jail.
> Using
> \[**auto**]
> will set it to the next available port.

**ip** *jailname* \[**all** | *address*]

> Print or set the whitelisted IP
> \[*address*]
> for an evobackup jail.
> \[**all**]
> allows unrestricted access and is the default.

**inc**

> Generate incremental backups

**rm**

> Remove old incremental backups

# FILES

*/etc/default/bkctld*

> Template for
> bkctld.conf(5)

*/usr/share/bkctld/incl.tpl*

> Default rules for the incremental backups are stored here.

# EXAMPLES

Before creating a jail and backing up a client,
the backup server administrator will need:

*	The host name of the client system.

*	The public RSA
	ssh(1)
	key for the
	"root"
	user of the client system,
	it is recommended the private key be password-less if automation is desired.

*	The IPv4 address of the client system is needed
	if the administrator wishes to maintain a whitelist,
	see
	*FIREWALL\_RULES*
	in
	bkctld.conf(5)

He can then create the jail:

	# bkctld init CLIENT_HOST_NAME
	# bkctld key CLIENT_HOST_NAME /root/CLIENT_HOST_NAME.pub
	# bkctld ip CLIENT_HOST_NAME CLIENT_IP_ADDRESS
	# bkctld start CLIENT_HOST_NAME
	# bkctld status CLIENT_HOST_NAME

And override the default
evobackup-incl(5)
rules

	# $EDITOR /etc/evobackup/CLIENT_HOST_NAME

To sync itself,
the client server will need to install
rsync(1).
It can then be run manually:

	# rsync -av -e "ssh -p JAIL_PORT" /home/ root@BACKUP_SERVER:/var/backup/home/

If a more automated setup is required,
a script can be written in any programming language.
In this case,
it may be useful to validate the backup server's identity before hand.

	# ssh -p JAIL_PORT BACKUP_SERVER

A
bash(1)
example to be run under the
"root"
user's
crontab(5)
can be found in the
[source repository](https://gitea.evolix.org/evolix/evobackup/src/branch/master/zzz_evobackup)

# SEE ALSO

rsync(1),
ssh-keygen(1),
bkctld(5),
evobackup-incl(5),
chroot(8),
cron(8),
sshd(8)

# AUTHORS

Victor Laborie

OpenBSD 6.4 - December 27, 2018
