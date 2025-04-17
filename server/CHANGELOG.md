# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project does not follow semantic versioning.
The **major** part of the version is the year
The **minor** part changes is the month
The **patch** part changes is incremented if multiple releases happen the same month

## [Unreleased]

### Added

* bkctld-report: New command to generate a simple reporting (jails with their settings and current incs on disk)

### Changed

* new default location for canary file

### Deprecated

### Removed

### Fixed

* bkctld-archive : Remove firewall rules when archiving a jail (fixes #69)

### Security


## [25.01] - 2024-01-27

### Added

* bkctld-check-setup: Check how many incs operation are running (Critical if >=2)
* bkctld-check-setup: Check if inc and rm operations are running simultaneously (Warning if yes)
* bkctld-check-setup: Check if inc creation time (in the last 10 days) is bellow given thresholds
* bkctld-check-setup: Check if there is more than 1 unfinished inc operation
* bkctld-inc: Save inc creation time
* Directory /var/lib/bkctld to store internal bkctld informations
* Munin plugins for bkctld [#64](https://gitea.evolix.org/evolix/evobackup/pulls/64)

### Changed

* bkctld-inc: Add log message at begining/end of operations (with the inc name)
* bkctld-inc: Inverted log message priorities (progress messages are notice, and start/finish are info)
* bkctld-rm: Add log message at begining/end of operations
* bkctld-rm: Inverted log message priorities (progress messages are notice, and start/finish are info)
* bkctld-status: Disable padding for the last column [#54](https://gitea.evolix.org/evolix/evobackup/pulls/54) 

### Deprecated

### Removed

### Fixed

* munin : bkctld_incs > Correct the counting logic of the plugin

### Security


## [24.10] - 2024-10-10

### BREAKING

This release change the internals of bkctld. Instead of relying on `chroot`, it now uses `systemd-nspawn`.
This change required to reorganize the jail the jail folder structure in a new form (called `version 2`). And also brings the possibility to have most of the jail folder read-only.

The convertion to this format is required to do any actions on the jail (start/stop) or change any of it's settings (key, ip...)

The jail folder structure before : 

```
# tree -L 2 /backup/jails/old-jail/ 
/backup/jails/old-jail/   # <--- Jail root 
├── bin -> ./usr/bin 
├── dev
├── etc
│   ├── ...
│   └── ssh
├── ...
├── usr 
│   └── ...
└── var
     ├── backup   # <--- Where data was expected to be pushed
     ├── log
     ├── run -> ../run
     └── tmp
```

And after the convertion :

```
# tree -L 2 /backup/jails/new-jail/
/backup/jails/new-jail/
├── data
│   └── Things
├── root        # <--- New jail root (Read-Only)
│   ├── bin -> ./usr/bin
│   ├── data    # <- Bind mount from /backup/jails/new-jail/data (Read-Write)
│   ├── dev
│   ├── etc
│   ├── start.sh
│   ├── ...
│   └── var    # <- Bind mount from /backup/jails/new-jail/var (Read-Write)
└── var
     ├── backup # <- Bind mount from /backup/jails/new-jail/data (Read-Write) 
     ├── dev
     ├── log
     └── run -> ../run
```


### Added

* New command bkctld logs : Display the logs of the sshd server for a given jail
* New command bkctld convert-v2 : Convert a given jail in the v2 format for nspawn
* New command bkctld jail-version : Return the jail format

### Changed

* Disallow jail actions/configuration commands if the jail is deemed not up-to-date
* bkcltd-check-canary: Canary check will raise a `WARNING` instead of a `CRITICAL` if yesterday date was found

### Fixed

* Test presence of old config file before trying to delete it
* Use correct variable when detecting local sshrc template
* bkcltd-rm: hide over allocation message

## [22.11] - 2022-11-28

### Added

* check-canary: new subcommand to check canary files and content

### Changed

* stats: filter active jails and columnize the output

## [22.07] - 2022-07-20

### Changed

* check-setup: check minifirewall version only if minifirewall is present
* check-setup: get minifirewall version from internal variable (there is no other backward compatible way)
* check-setup: use findmnt with mountpoint instead of target

## [22.06] - 2022-06-28

### Added

* bkctld-init: create "incs/\<jail\>" directory for jails

### Fixed

* shell syntax error when ${btrfs_bin} variable is empty
* read_variable + read_numerical_variable: keep the last found value only
* Debian 8 findmnt(8) support

### Security

## [22.04] - 2022-04-20

### Added

* Run the test suite on Bullseye (ext4/btrfs) in addition of Stretch and Buster (ext4/btrfs)
* Tell sed to follow symlinks
* Add a header in `bkctld status` output and improved columns width.
* bkctld-check-setup: compatibility with minifirewall 22.03+

### Changed

* change versioning pattern

## [2.12.0] - 2021-11-02

### Changed

* btrfs depends on the btrfd-progs package instead of btrfs-tools

## [2.11.1] - 2021-06-30

### Changed

* bkctld-rename: abort operation if incs exist with the new name

## [2.11.0] - 2021-06-29

### Changed

* bkctld-remove: remove config directory

### Fixed

* force flag must be exported

## [2.10.0] - 2021-06-29

### Added

* bkctld-archive: archive a jail
* bkctld-rename: rename a jail and all its incs and configuration…

### Removed

* Do not print out date, log level and process name on stdout/stderr
## [2.9.0] - 2021-02-22

### Added

* bkctld-init: install check_policy template
* bkctld-upgrade-config: install check_policy template if missing
* test: bkctld check-incs shouldn't fail without incs_policy file

### Changed

* Rename incs_policy template
* bkctld-check-incs: Correct shellsheck warnings

### Fixed

* tests: clean jail configuration after each test
* bkctld-check-incs: Protect `jail_config_epoch`

## [2.8.0] - 2020-11-28

### Added

* bkctld: new inc-lock and inc-unlock command

## [2.7.1] - 2020-11-28

### Fixed

* bkctld-upgrade-config is executable

## [2.7.0] - 2020-11-13

### Added

* bkctld: add a [-f|--force] option to remove confirmation on some commands
* bkctld-remove: confirmation before removal of jails if not in force mode
* bkctld-rm: delete empty jails in incs directory

### Changed

* Better help message composition and formating
* bkctld-rm: list jails from incs directory

## [2.6.0] - 2020-10-07

### Added

* bkctld: add a [-V|--version] option to display release number
* bkctld: add a [-h|--help|-?] option to display help message

## [2.5.1] - 2020-10-07

### Changed

* bkctld: Replace xargs with a simple loop

## [2.5.0] - 2020-09-25

### Fixed

* restore compatibility with Debian <10

## [2.4.1] - 2020-08-28

### Added

* jails and incs lists are sorted alphanumerically

### Fixed

* bkctld-check-setup: forgot to increment the summary

## [2.4.0] - 2020-08-19

### Added

* New command bkctld upgrade-config to move the legacy config file "/etc/evobackup/<jail>" to the new config structure "/etc/evobackup/<jail>.d/incs_policy"

### Changed

* bkctld-update: start jail after upgrade if it was started before
* bkctld: don't replace SSH host keys when creating/updating a jail
* Split check into check-jails and check-setup
* bkctld-check-jails checks if jails
* bkctld-check-setup checks if the partition is mounted and writable, if firewall is configured and if all jails are in their expected state
* create new ssh keys for new jails instead of copying those from the host

## [2.3.3] - 2020-05-28

### Fixed

* On sync, add trailing slash to rsync command

## [2.3.2] - 2020-05-03

### Changed

* Display help message if mandatory arguments are missing.
* Don't recreate jail on sync if it already exists
* Don't sync the whole firewall file, just remake rules for the current jail
* On sync, if local jail is running, reload remote jail if already running, start if not

## [2.3.1] - 2020-04-22

### Added

* State the age of the current "rm" process when killing it
* Give the new PID after killing the previous "rm" process

### Fixed

* typos
* forgotten quotes

## [2.3.0] - 2020-04-20

### Changed

* Rewrite log messages and format

## [2.2.2] - 2020-04-19

### Changed

* Reorganize temp files and lock files

### Fixed

* Properly call subcommands in bkctld-check-incs and bkctld-check-last-incs
* Log start time in bkctld-rm

## [2.2.1] - 2020-04-18

### Changed

* check-incs.sh and check-last-incs.sh are embedded in bkctld

## [2.2.0] - 2020-04-17

### Added

* Shellcheck directives to have 0 warnings and errors
* Ability to override critical/warning thresholds per jail for bkctld-check
* Support new location for jail configuration (/etc/evobackup/<jail_name>.d/)
* Lock per jail and inc when creating incs
* Global lock when removing incs (kill the currently running instance)
* Create a blank SSH "authorized_keys" file on jail init
* Many new tests with BATS
* Check for firewall configuration in bkcld-check
* Run the test suite on Buster (ext4/btrfs) in addition of Stretch (ext4/btrfs)

### Changed

* Extract variables and heper functions to reduce repetition of knowledge
* Consistent naming of variables in scripts and functions
* Consistent log messages between functions ad commands
* Raise errors if required function arguments are missing
* Configure locales in Vagrant VM
* Split BATS tests file and use helper functions
* Improve "lib" detection
* Revamp the README
