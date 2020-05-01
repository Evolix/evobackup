# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

* Display help message if mandatory arguments are missing.
* Don't recreate jail on sync if it already exists
* Don't sync the whole firewall file, just remake rules for the current jail

### Deprecated

### Removed

### Fixed

### Security

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
