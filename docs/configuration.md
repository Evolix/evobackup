# CONFIGURATION VARS

bkctld configuration has to be set in /etc/default/bkctld file.

## REQUIREDS VARS

Default required vars are defined in bkctld script. Alter them to override default values.

* CONFDIR (default: /etc/evobackup) : Dir where incremental backup is configured. See INCS CONFIGURATION section for details.
* JAILDIR (default : /backup/jails) : Dir for jail's root dir. BTRFS recommended.
* INCDIR (default : /backups/incs) : Dir where incremental backup is stored. BTRFS recommended.
* TPLDIR (default : /usr/share/bkctld) : Dir where jail template file is stored.
* LOCALTPLDIR (default : /usr/local/share/bkctld) : Dir for surcharge jail templates.
* LOGLEVEL (default : 6) : Define loglevel, based on syslog severity level.

## OPTIONALS VARS

Optionnals vars are no default value. No set them desactivate correspondant fonctionnality.

* FIREWALL_RULES (default: no firewall auto configuration) : Configuration file were firewall was configured to allow jail access. This file must be sourced by your firewall configuration tool.
