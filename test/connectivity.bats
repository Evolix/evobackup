#!/usr/bin/env bats
# shellcheck disable=SC1089,SC1083,SC2154

load test_helper

@test "Without SSH key" {
    run cat "${JAILPATH}/root/.ssh/authorized_keys"
    assert_equal "$output" ""
}

@test "With SSH key" {
    keyfile=/root/bkctld.key.pub
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" "${keyfile}"
    # The key should be present in the SSH authorized_keys file
    run cat "${JAILPATH}/root/.ssh/authorized_keys"
    assert_equal "$output" "$(cat ${keyfile})"
}

@test "Custom port" {
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    # A jail should be accessible on the specified SSH port
    run nc -vz 127.0.0.1 "${PORT}"
    assert_success
}

@test "No IP restriction" {
    # A jail has no IP restriction by default in SSH config
    run grep "root@0.0.0.0/0" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "Single IP restriction" {
    # When an IP is added for a jail
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    # An IP restriction should be present in SSH config
    run grep "root@10.0.0.1" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "Multiple IP restrictions" {
    # When multiple IP are added for a jail
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.2"
    # The corresponding IP restrictions should be present in SSH config
    run grep -E -o "root@10.0.0.[0-9]+" "${JAILPATH}/etc/ssh/sshd_config"

    assert_line "root@10.0.0.1"
    assert_line "root@10.0.0.2"
}

@test "Removing IP restriction" {
    # Add an IP
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    # Remove IP
    /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "0.0.0.0/0"
    # All IP restrictions should be removed from SSH config
    run grep "root@0.0.0.0/0" "${JAILPATH}/etc/ssh/sshd_config"
    assert_success
}

@test "Missing AllowUsers" {
    # Remove AllowUsers directive in SSH config
    sed -i '/^AllowUsers/d' "${JAILPATH}/etc/ssh/sshd_config"
    # An error should be raised when trying to add an IP restriction
    run /usr/lib/bkctld/bkctld-ip "${JAILNAME}" "10.0.0.1"
    assert_failure
}

@test "SSH connectivity" {
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

@test "Rsync connectivity" {
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
