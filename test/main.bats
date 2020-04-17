#!/usr/bin/env bats
# shellcheck disable=SC1089,SC1083,SC2154

load test_helper

@test "Filesystem type" {
    if is_btrfs "/backup"; then
        # On a btrfs filesystem, the jail should be a btrfs volume
        run is_btrfs "${JAILPATH}"
        assert_success
    else
        # On an ext4 filesystem, the jail should be a regular directory
        run test -d "${JAILPATH}"
        assert_success
    fi
}

@test "A jail should be able to be started" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")
    # A started jail should have an SSH pid file
    run ps --pid "${pid}"
    assert_success
}

@test "A jail should be able to be stopped" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")
    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not have an SSH pid file
    run ps --pid "${pid}"
    assert_failure
}

@test "A jail should be able to be reloaded" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-reload "${JAILNAME}"
    # A reloaded jail should mention the restart in the authlog
    run grep "Received SIGHUP; restarting." "${JAILPATH}/var/log/authlog"
    assert_success
}

@test "A jail should be able to be restarted" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid_before=$(cat "${JAILPATH}/${SSHD_PID}")

    /usr/lib/bkctld/bkctld-restart "${JAILNAME}"
    pid_after=$(cat "${JAILPATH}/${SSHD_PID}")

    # A restarted jail should have a different pid
    refute_equal "${pid_before}" "${pid_after}"
}

@test "Status should return information" {
    run /usr/lib/bkctld/bkctld-status "${JAILNAME}"
    assert_success
}

@test "ON/OFF status can be retrived with 'is-on'" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    # A started jail should report to be ON
    run /usr/lib/bkctld/bkctld-is-on "${JAILNAME}"
    assert_success

    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not report to be ON
    run /usr/lib/bkctld/bkctld-is-on "${JAILNAME}"
    assert_failure
}
