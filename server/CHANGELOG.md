# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Deprecated

### Removed

### Fixed

* shell syntax error when ${btrfs_bin} variable is empty

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
