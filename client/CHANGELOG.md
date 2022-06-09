# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

* Use --dump-dir instead of --backup-dir to supress dump-server-state warning
* Do not use rsync compression
* Replace rsync option --verbose by --itemize-changes
# update-evobackup-canary : do not use GNU date, for it to be compatible with OpenBSD

### Deprecated

### Removed

### Fixed

* Make start_time and stop_time compatible with OpenBSD

### Security

## [22.03]

Split client and server parts of the project
