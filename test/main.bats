#!/usr/bin/env bats

setup() {
    port=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    date=$(date +"%Y-%m-%d-%H")
    inode=$(stat --format=%i /backup)
    rm -f /root/bkctld.key* && ssh-keygen -t rsa -N "" -f /root/bkctld.key -q
    . /usr/lib/bkctld/config
    JAILNAME=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1)
}

teardown() {
    /usr/lib/bkctld/bkctld-remove "${JAILNAME}" && rm -rf "${INCDIR}/*"
}

@test "init" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    inode=$(stat --format=%i /backup)
    run test -d "${CONFDIR}/${JAILNAME}"
    [ "${status}" -eq 0 ]
}

@test "start" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${RUNDIR}/${JAILNAME}/sshd.pid")
    run ps --pid "${pid}"
    [ "${status}" -eq 0 ]
}

@test "stop" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    pid=$(cat "${RUNDIR}/${JAILNAME}/sshd.pid")
    /usr/lib/bkctld/bkctld-stop "${JAILNAME}"
    run ps --pid "${pid}"
    [ "${status}" -ne 0 ]
}

@test "reload" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-reload "${JAILNAME}"
    run grep "Received SIGHUP; restarting." "${JAILDIR}/${JAILNAME}/var/log/authlog"
    [ "${status}" -eq 0 ]
}

@test "restart" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    bpid=$(cat "${RUNDIR}/${JAILNAME}/sshd.pid")
    /usr/lib/bkctld/bkctld-restart "${JAILNAME}"
    apid=$(cat "${RUNDIR}/${JAILNAME}/sshd.pid")
    [ "${bpid}" -ne "${apid}" ]
}

@test "status" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    run /usr/lib/bkctld/bkctld-status "${JAILNAME}"
    [ "${status}" -eq 0 ]
}

@test "key" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub
    run cat "${CONFDIR}/${JAILNAME}/ssh/authorized_keys"
    [ "${status}" -eq 0 ]
    [ "${output}" = $(cat /root/bkctld.key.pub) ]
}

@test "port" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${port}"
    run nc -vz 127.0.0.1 "${port}"
    [ "${status}" -eq 0 ]
}

@test "inc" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-inc
    if [ "${inode}" -eq 256 ]; then
        run stat --format=%i "${MOUNT_POINT}/${JAILNAME}/${date}"
        [ "${output}" -eq 256 ]
    else
        run test -d "${MOUNT_POINT}/${JAILNAME}/${date}"
        [ "${status}" -eq 0 ]
    fi
}

@test "ssh" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${port}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub
    run ssh -p "${port}" -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 ls
    [ "$status" -eq 0 ]
}

@test "rsync" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    /usr/lib/bkctld/bkctld-start "${JAILNAME}"
    /usr/lib/bkctld/bkctld-port "${JAILNAME}" "${port}"
    /usr/lib/bkctld/bkctld-key "${JAILNAME}" /root/bkctld.key.pub
    run rsync -a -e "ssh -p ${port} -i /root/bkctld.key -oStrictHostKeyChecking=no" /tmp/ root@127.0.0.1:/var/backup/
    [ "$status" -eq 0 ]
}

@test "check-ok" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 0 ]
}

@test "check-warning" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    touch --date="$(date -d -2days)" "${LOGDIR}/${JAILNAME}/lastlog"
    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 1 ]
}

@test "check-critical" {
    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
    touch --date="$(date -d -3days)" "${LOGDIR}/${JAILNAME}/lastlog"
    run /usr/lib/bkctld/bkctld-check
    [ "$status" -eq 2 ]
}
