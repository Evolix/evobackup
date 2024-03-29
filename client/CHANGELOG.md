# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [22.12]
### Changed

* Use --dump-dir instead of --backup-dir to suppress dump-server-state warning
* Do not use rsync compression
* Replace rsync option --verbose by --itemize-changes
* Add canary to zzz_evobackup
* update-evobackup-canary: do not use GNU date, for it to be compatible with OpenBSD
* Add AGPL License and README
* Script now depends on Bash
* tolerate absence of mtr or traceroute
* Only one loop for all Redis instances
* remodel how we build the rsync command
* use sub shells instead of moving around
* Separate Rsync for the canary file if the main Rsync has finished without errors

### Removed

* No more fallback if dump-server-state is missing

### Fixed

* Make start_time and stop_time compatible with OpenBSD

## [22.03]

Split client and server parts of the project
