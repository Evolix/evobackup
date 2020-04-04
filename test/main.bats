#!/usr/bin/env bats

load test_helper

setup() {
    . /usr/lib/bkctld/includes

    rm -f /root/bkctld.key*
    ssh-keygen -t rsa -N "" -f /root/bkctld.key -q

    grep -qE "^BACKUP_DISK=" /etc/default/bkctld || echo "BACKUP_DISK=/dev/vdb" >> /etc/default/bkctld

    JAILNAME=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1)
    JAILPATH="/backup/jails/${JAILNAME}"
    INCSPATH="/backup/incs/${JAILNAME}"
    PORT=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    INC_NAME=$(date +"%Y-%m-%d-%H")

    inode=$(stat --format=%i /backup)

    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
}

teardown() {
    /usr/lib/bkctld/bkctld-remove "${JAILNAME}" && rm -rf "${INCSPATH}"
}

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

@test "init-incs-policy" {
    # An incs_policy file should exist
    run test -e "${CONFDIR}/${JAILNAME}.d/incs_policy"
    [ "${status}" -eq 0 ]
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

@test "key-absent" {
    run cat "${JAILPATH}/root/.ssh/authorized_keys"
    assert_equal "$output" ""
}

@test "key-present" {
    keyfile=/root/bkctld.key.pub
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" "${keyfile}"
    # The key should be present in the SSH authorized_keys file
    run cat "${JAILPATH}/root/.ssh/authorized_keys"
    assert_equal "$output" "$(cat ${keyfile})"
}

@test "port" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    # A jail should be accessible on the specified SSH port
    run nc -vz 127.0.0.1 "${PORT}"
    assert_success
}

@test "ip-none" {
    # A jail has no IP restriction by default in SSH config
    run grep "root@0.0.0.0/0" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "ip-single" {
    # When an IP is added for a jail
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    # An IP restriction should be present in SSH config
    run grep "root@10.0.0.1" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "ip-multiple" {
    # When multiple IP are added for a jail
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.2"
    # The corresponding IP restrictions should be present in SSH config
    run grep -E -o "root@10.0.0.[0-9]+" "${JAILPATH}/etc/ssh/sshd_config"

    assert_line "root@10.0.0.1"
    assert_line "root@10.0.0.2"
}

@test "ip-remove" {
    # Add an IP
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    # Remove IP
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "0.0.0.0/0"
    # All IP restrictions should be removed from SSH config
    run grep "root@0.0.0.0/0" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "inc" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-inc

    if [ "${inode}" -eq 256 ]; then
        # On a btrfs filesystem, the inc should be a btrfs volume
        run stat --format=%i "${INCSPATH}/${INC_NAME}"
        assert_success 256
    else
        # On an ext4 filesystem, the inc should be a regular directory
        run test -d "${INCSPATH}/${INC_NAME}"
        assert_success
    fi
}

@test "ssh" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub

    ssh_options="-p ${PORT} -i /root/bkctld.key -oStrictHostKeyChecking=no"

    # A started jail should be accessible via SSH
    run ssh ${ssh_options} root@127.0.0.1 ls
    assert_success

    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not be accessible via SSH
    run ssh ${ssh_options} root@127.0.0.1 ls
    assert_failure
}

@test "rsync" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub

    ssh_options="-p ${PORT} -i /root/bkctld.key -oStrictHostKeyChecking=no"
    # A started jail should be accessible via Rsync
    run rsync -a -e "ssh ${ssh_options}" /tmp/ root@127.0.0.1:/var/backup/
    assert_success

    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    # A stopped jail should not be accessible via Rsync
    run rsync -a -e "${ssh_options}" /tmp/ root@127.0.0.1:/var/backup/
    assert_failure
}

@test "check-default-ok" {
    touch "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a freshly connected jail should be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "0"
}

@test "check-default-warning" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 2 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "1"
}

@test "check-default-critical" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 3 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "2"
}

@test "check-custom-ok" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    echo "CRITICAL=120" >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    echo "WARNING=96" >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    # With custom values (5 days critical, 4 days warning),
    # a 3 days old jail should be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "0"
}

@test "check-custom-warning" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    echo "CRITICAL=96" >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    echo "WARNING=48"  >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    # With custom values (4 days critical, 3 days warning),
    # a 3 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "1"
}

@test "check-custom-critical" {
    lastlog_date=$(date -d -10days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    echo "CRITICAL=96" >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    echo "WARNING=48"  >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    # With custom values (4 days critical, 3 days warning),
    # a 10 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "2"
}

@test "check-disabled-warning" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    echo "WARNING=0"  >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    # With custom values (warning disabled, default critical),
    # a 2 days old jail should still be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "$status" "0"
}

@test "check-disabled-critical" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    echo "CRITICAL=0"  >> "/etc/evobackup/${JAILNAME}.d/check_policy"
    # With custom values (critical disabled, default warning),
    # a 3 days old jail should only be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert [ "$status" = "1" ]
}
