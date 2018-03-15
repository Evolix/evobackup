#!/usr/bin/env bats

setup() {
    bkctld init test
}

teardown() {
    bkctld remove all
}

@test "ok" {
    run /usr/lib/nagios/plugins/check_bkctld
    [ "$status" -eq 0 ]
}

@test "warning" {
    touch --date="$(date -d -2days)" /backup/jails/*/var/log/lastlog
    run /usr/lib/nagios/plugins/check_bkctld
    [ "$status" -eq 1 ]
}

@test "critical" {
    touch --date="$(date -d -3days)" /backup/jails/*/var/log/lastlog
    run /usr/lib/nagios/plugins/check_bkctld
    [ "$status" -eq 2 ]
}
