#!/usr/bin/env bats

load test_helper

@test "init-filesystem" {
    inode=$(stat --format=%i /backup)
    if [ "${inode}" -eq 256 ]; then
        # On a btrfs filesystem, the jail should be a btrfs volume
        run stat --format=%i "${JAILPATH}"
        [ "${output}" -eq 256 ]
    else
        # On an ext4 filesystem, the jail should be a regular directory
        run test -d "${JAILPATH}"
        [ "${status}" -eq 0 ]
    fi
}

@test "start" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")
    # A started jail should have an SSH pid file
    run ps --pid "${pid}"
    assert_success
}

@test "stop" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")
    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not have an SSH pid file
    run ps --pid "${pid}"
    assert_failure
}

@test "reload" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-reload "${JAILNAME}"
    # A reloaded jail should mention the restart in the authlog
    run grep "Received SIGHUP; restarting." "${JAILPATH}/var/log/authlog"
    assert_success
}

@test "restart" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid_before=$(cat "${JAILPATH}/${SSHD_PID}")

    /usr/lib/bkctld/bkctld-restart "${JAILNAME}"
    pid_after=$(cat "${JAILPATH}/${SSHD_PID}")

    # A restarted jail should have a different pid
    refute_equal "${pid_before}" "${pid_after}"
}

@test "status" {
    run /usr/lib/bkctld/bkctld-status "${JAILNAME}"
    assert_success
}

@test "is-on" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    # A started jail should report to be ON
    run /usr/lib/bkctld/bkctld-is-on "${JAILNAME}"
    assert_success

    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not report to be ON
    run /usr/lib/bkctld/bkctld-is-on "${JAILNAME}"
    assert_failure
}
