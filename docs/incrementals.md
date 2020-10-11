evobackup-incs-policy(5) - File Formats Manual

# NAME

**evobackup-incs-policy** - incremental backup configuration

# SYNOPSIS

> \+%Y-%m-%d.-%day

# DESCRIPTION

Located by default in
*/etc/evobackup/*,
each
**evobackup-incs-policy**
file is named after the
bkctld(8)
backup for which the rules it contains must apply.

The rules it defines decide which incremental backups are kept when running

	# bkctld incs-prune

Each line defines a single rule.
The first part of the rule describes when the backup was taken,
the second part decides how long to keep it.
Lines beginning with the
'#'
character are comments and are ignored.
The order of the rules does not matter.

Evobackups that do not have their nominal
**evobackup-incs-policy**
file use the default rules defined in
*/usr/share/bkctld/incs-policy.tpl*

# EXAMPLES

Keep today's backup:

	+%Y-%m-%d.-0day

Keep yesterday's backup:

	+%Y-%m-%d.-1day

Keep the first day of this month:

	+%Y-%m-01.-0month

Keep the first day of last month:

	+%Y-%m-01.-1month

Keep backups for every 15 days:

	+%Y-%m-01.-1month
	+%Y-%m-15.-1month

Keep a backup of the first day of january:

	+%Y-01-01.-1month

Keep backups of the last 4 days and the first day of the last 2 months:

	+%Y-%m-%d.-0day
	+%Y-%m-%d.-1day
	+%Y-%m-%d.-2day
	+%Y-%m-%d.-3day
	+%Y-%m-01.-0month
	+%Y-%m-01.-1month

# SEE ALSO

bkctld(8),
cron(8),
*/etc/evobackup/tpl/incs-policy.tpl*

OpenBSD 6.4 - December 28, 2018
