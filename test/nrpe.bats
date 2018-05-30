#!/usr/bin/env bats

setup() {
    bkctld init test
}

teardown() {
    bkctld remove all
}

@test "ok" {
    run bkctld check
    [ "$status" -eq 0 ]
}

@test "warning" {
    touch --date="$(date -d -2days)" /backup/jails/*/var/log/lastlog
    run bkctld check
    [ "$status" -eq 1 ]
}

@test "critical" {
    touch --date="$(date -d -3days)" /backup/jails/*/var/log/lastlog
    run bkctld check
    [ "$status" -eq 2 ]
}
