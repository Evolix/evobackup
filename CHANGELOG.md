# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

* Shellcheck directives to have 0 warnings and errors
* Ability to override critical/warning thresholds per jail for bkctld-check
* Support new location for jail configuration (/etc/evobackup/<jail_name>.d/)
* Lock per jail and inc when creating incs
* Global lock when removing incs (kill the currently running instance)
* Create a blank SSH "authorized_keys" file on jail init
* Many new tests with BATS
* Check for firewall configuration in bkcld-check

### Changed

* Extract variables and heper functions to reduce repetition of knowledge
* Consistent naming of variables in scripts and functions
* Consistent log messages between functions ad commands
* Raise errors if required function arguments are missing
* Configure locales in Vagrant VM
* Split BATS tests file and use helper functions
* Improve "lib" detection

### Deprecated

### Removed

### Fixed

### Security
