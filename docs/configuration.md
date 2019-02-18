BKCTLD.CONF(5) - File Formats Manual

# NAME

**bkctld.conf** - configuration file for
bkctld(8)

# SYNOPSIS

> name=\[value]

# DESCRIPTION

The
**bkctld.conf**
file contains variables that override the behavior of the
bkctld(8)
script.
By default, it is located at
*/etc/default/bkctld*.

Each line must be a valid
bash(1)
variable definition.
Lines beginning with the
'#'
character are comments and are ignored.
The order of the definitions does not matter.

The following variables may be defined:

*CONFDIR*

> Directory where
> evobackup-incl(5)
> files are kept.
> It's default value is
> */etc/evobackup/*.

*JAILDIR*

> Directory where the jails are stored,
> it is recommended that this be inside a BTRFS file system.
> It's default value is
> */backup/jails/*.

*INCDIR*

> Directory where incremental backups are stored,
> it is recommended that this be inside a BTRFS file system.
> It's default value is
> */backup/incs/*.

*TPLDIR*

> Directory where the default configuration files are stored.
> It's default value is
> */usr/share/bkctld/*.

*LOCALTPLDIR*

> Directory where custom configuration files are stored.
> It's default is
> */usr/local/share/bkctld/*.

*LOGLEVEL*

> Defines the amount of information to log, follows the same scale as in
> &lt;*syslog.h*>
> and defaults to 6.

*FIREWALL\_RULES*

> Configuration file containing the firewall rules that govern jail access.
> This file must be sourced by your firewall.
> It does not have a default value and, if unset,
> bkctld(8)
> will not automatically update the firewall.

# SEE ALSO

bash(1),
evobackup-incl(5),
bkctld(8)

OpenBSD 6.4 - December 28, 2018
