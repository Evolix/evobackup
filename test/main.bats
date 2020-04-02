#!/usr/bin/env bats

setup() {
    . /usr/lib/bkctld/includes

    rm -f /root/bkctld.key*
    ssh-keygen -t rsa -N "" -f /root/bkctld.key -q

    JAILNAME=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1)
    JAILPATH="/backup/jails/${JAILNAME}"
    INCSPATH="/backup/incs/${JAILNAME}"
    PORT=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    INC_NAME=$(date +"%Y-%m-%d-%H")

    inode=$(stat --format=%i /backup)
}

teardown() {
    /usr/lib/bkctld/bkctld-remove "${JAILNAME}" && rm -rf "${INCSPATH}"
}

@test "init" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    inode=$(stat --format=%i /backup)
    if [ "${inode}" -eq 256 ]; then
        run stat --format=%i "${JAILPATH}"
        [ "${output}" -eq 256 ]
    else
        run test -d "${JAILPATH}"
        [ "${status}" -eq 0 ]
    fi

    run test -e "${CONFDIR}/${JAILNAME}.d/incs_policy"
    [ "${status}" -eq 0 ]
}

@test "start" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")

    run ps --pid "${pid}"
    [ "${status}" -eq 0 ]
}

@test "stop" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${JAILPATH}/${SSHD_PID}")
    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"

    run ps --pid "${pid}"
    [ "${status}" -ne 0 ]
}

@test "reload" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-reload "${JAILNAME}"

    run grep "Received SIGHUP; restarting." "${JAILPATH}/var/log/authlog"
    [ "${status}" -eq 0 ]
}

@test "restart" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    bpid=$(cat "${JAILPATH}/${SSHD_PID}")
    /usr/lib/bkctld/bkctld-restart "${JAILNAME}"
    apid=$(cat "${JAILPATH}/${SSHD_PID}")

    [ "${bpid}" -ne "${apid}" ]
}

@test "status" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"

    run /usr/lib/bkctld/bkctld-status "${JAILNAME}"
    [ "${status}" -eq 0 ]
}

@test "key" {
    keyfile=/root/bkctld.key.pub
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" "${keyfile}"
    expected=$(cat ${keyfile})

    run cat "${JAILPATH}/root/.ssh/authorized_keys"
    [ "${status}" -eq 0 ]
    [ "${output}" = "${expected}" ]
}

@test "port" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"

    run nc -vz 127.0.0.1 "${PORT}"
    [ "${status}" -eq 0 ]
}

@test "inc" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-inc

    if [ "${inode}" -eq 256 ]; then
        run stat --format=%i "${INCSPATH}/${INC_NAME}"
        [ "${output}" -eq 256 ]
    else
        run test -d "${INCSPATH}/${INC_NAME}"
        [ "${status}" -eq 0 ]
    fi
}

@test "ssh" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub

    run ssh -p "${PORT}" -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 ls
    [ "$status" -eq 0 ]
}

@test "rsync" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${PORT}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub

    run rsync -a -e "ssh -p ${PORT} -i /root/bkctld.key -oStrictHostKeyChecking=no" /tmp/ root@127.0.0.1:/var/backup/
    [ "$status" -eq 0 ]
}

@test "check-ok" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"

    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 0 ]
}

@test "check-warning" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    touch --date="$(date -d -2days --iso-8601=seconds)" "${JAILPATH}/var/log/lastlog"

    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 1 ]
}

@test "check-critical" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    touch --date="$(date -d -3days --iso-8601=seconds)" "${JAILPATH}/var/log/lastlog"

    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 2 ]
}
