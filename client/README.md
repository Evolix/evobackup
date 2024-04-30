EvoBackup — the client side
===========================

_What you install on the servers you want to backup._

## Design

### backup script

The tip of the iceberg is a script (often called `zzz_evobackup` because it is executed by cron at the very end of the _daily_ tasks list).

This is where you setup **what**, **how** and **where** to backup on remote server(s).

There are 2 main phases in the backup :

1. **local tasks**: everything you want to do locally (save state information, dump databases…).
2. **sync tasks**: which data (including what has been prepared in the local phase) you want to send to remote servers.

### libraries

The vast majority of the logic is in libraries, to help maintaining them without having to modify the backup script.

They contain mostly _dump_ functions that are called from the backup script.

Those functions contain a lot of code for logging, options parsing, error management, and some code specific to the dump task.

### utility script

A scripts named `evobackupctl` helps initializing a backup jail on remote servers or install the backup script where you want.

## Install and update

To install, copy these files :

* `lib/*` → `/usr/local/lib/evobackup`
* `bin/evobackupctl` → `/usr/local/bin/evobackupctl`

To update, simply overwrite them, since their content should (must?) not be customized locally.

## Usage

### backup script

#### minimal configuration

##### mail notifications

The absolute minimum you must do is set the `MAIL` variable to the email address you want to be notified at.

##### sync tasks

If you want to sync files to a remote server, you have to set the `SERVERS` variable with at least one host and port.
Beware that the default `evolix-system` _sync_ doesn't sync `/home`, `/srv`…

If you want to sync files to multiple groups of servers, you can add as many _sync_ sections as you want.
A _sync_ section must contain something like this :

~~~bash
# The name of the "sync" (visible in logs)
SYNC_NAME="evolix-system"
# List of servers
SERVERS=(
    host1:port1
    host2:port2
)
# List of paths to include in the sync
RSYNC_INCLUDES=(
    "${rsync_default_includes[@]}"
    /etc
    /root
    /var
)
# List of paths to exclude from the sync
RSYNC_EXCLUDES=(
    "${rsync_default_excludes[@]}"
)
# Actual sync command
sync "${SYNC_NAME}" "SERVERS[@]" "RSYNC_INCLUDES[@]" "RSYNC_EXCLUDES[@]"
~~~

##### local tasks

By default, the `local_tasks()` function only:

* executes [dump-server-state](https://gitea.evolix.org/evolix/dump-server-state) to put have a saved copy of a lot of information about the server
* saves a traceroute to some key network endpoints (using the `dump_traceroute()` function)

You can enable (by uncommenting) as many _dump_ functions as you want.

### advanced customization

Since this is a shell script, you can add any bash-compatible code you want.
If you do so you should read the libraries code to make sure that you don't overwrite existing functions.

##### sync tasks

If you don't want to sync files to any remote servers, you can simply replace the content of the `sync_tasks()` function by a no-op command (`:`).

`RSYNC_INCLUDES` and `RSYNC_EXCLUDES` refer to `${rsync_default_includes[@]}` and `${rsync_default_excludes[@]}` (defined in the `main.sh` library) to simplify the configuration. If you want to precisely customize the lists you can remove them and add you own.

##### local tasks

Existing _dump_ functions (as defined in libraries) are usable as-is, but you can also create your own local custom functions.
You have to define them in the backup script (or in a file that you source from the backup script).
You should prefix their name with `dump_` base your customization on the `dump_custom()` (documented in the backup script) to keep the boilerplate code (for logging, error management…).

You can customize some values inside the `setup_custom()`, like the server's hostname, the notification mail subject…

If you want to source libraries from a different path, you can change the `LIBDIR` variable at the end of the backup script.

### utility tool

The command is `evobackupctl`.

~~~
# evobackupctl --help
evobackupctl helps managing evobackup scripts

Options
 -h, --help                  print this message and exit
 -V, --version               print version and exit
     --jail-init-commands    print jail init commands
     --copy-template=PATH    copy the backup template to PATH

# evobackupctl --version
evobackupctl version 24.04

Copyright 2024 Evolix <info@evolix.fr>,
               Jérémy Lecour <jlecour@evolix.fr>.

evobackupctl comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions.
See the GNU General Public License v3.0 for details.
~~~

#### jail init commands

It prints a list of commands you can execute on remote backup servers to configure a backup "jail".

~~~
# evobackupctl --jail-init-commands
Copy-paste those lines on backup server(s) :
----------
SERVER_NAME=example-hostname
SERVER_IP=203.0.113.1
echo 'ssh-ed25519 xxxxxx root@example-hostname' > /root/${SERVER_NAME}.pub
bkctld init ${SERVER_NAME}
bkctld key ${SERVER_NAME} /root/${SERVER_NAME}.pub
bkctld ip ${SERVER_NAME} ${SERVER_IP}
bkctld start ${SERVER_NAME}
bkctld status ${SERVER_NAME}
grep --quiet --extended-regexp "^\s?NODE=" /etc/default/bkctld && bkctld sync ${SERVER_NAME}
----------
~~~

#### copy-template

It copies the backups script template to the path of your choice, nothing more.

~~~
# evobackupctl --copy-template /etc/cron.daily/zzz_evobackup
New evobackup script has been saved to '/etc/cron.daily/zzz_evobackup'.
Remember to customize it (mail notifications, backup servers…).
~~~
