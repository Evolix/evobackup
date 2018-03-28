#!/usr/bin/env bats

setup() {
    port=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    date=$(date +"%Y-%m-%d-%H")
    inode=$(stat --format=%i /backup)
    rm -f /root/bkctld.key* && ssh-keygen -t rsa -N "" -f /root/bkctld.key -q
    [ -f /etc/default/bkctld ] && . /etc/default/bkctld
    CONFDIR="${CONFDIR:-/etc/evobackup}"
    JAILDIR="${JAILDIR:-/backup/jails}"
    INCDIR="${INCDIR:-/backup/incs}"
    TPLDIR="${TPLDIR:-/usr/share/bkctld}"
    LOCALTPLDIR="${LOCALTPLDIR:-/usr/local/share/bkctld}"
    SSHD_PID="${SSHD_PID:-/run/sshd.pid}"
    SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
    AUTHORIZED_KEYS="${AUTHORIZED_KEYS:-/root/.ssh/authorized_keys}"
    FIREWALL_RULES="${FIREWALL_RULES:-}"
    LOGLEVEL="${LOGLEVEL:-6}"
}

teardown() {
    bkctld remove all && rm -rf "${INCDIR}/*"
}

@test "init" {
    bkctld init test
    if [ "${inode}" -eq 256 ]; then
        run stat --format=%i "${JAILDIR}/test"
        [ "${output}" -eq 256 ]
    else
        run test -d "${JAILDIR}/test"
        [ "${status}" -eq 0 ]
    fi
}

@test "update" {
    skip
}

@test "start" {
    bkctld init test
    bkctld start test
    pid=$(cat "${JAILDIR}/test/${SSHD_PID}")
    run ps --pid "${pid}"
    [ "${status}" -eq 0 ]
}

@test "stop" {
    bkctld init test
    bkctld start test
    pid=$(cat "${JAILDIR}/test/${SSHD_PID}")
    bkctld stop test
    run ps --pid "${pid}"
    [ "${status}" -ne 0 ]
}

@test "reload" {
    bkctld init test
    bkctld start test
    bkctld reload test
    run grep "Received SIGHUP; restarting." "${JAILDIR}/test/var/log/authlog"
    [ "${status}" -eq 0 ]
}

@test "restart" {
    bkctld init test
    bkctld start test
    bpid=$(cat "${JAILDIR}/test/${SSHD_PID}")
    bkctld restart test
    apid=$(cat "${JAILDIR}/test/${SSHD_PID}")
    [ "${bpid}" -ne "${apid}" ]
}

@test "status" {
    bkctld init test
    run bkctld status test
    [ "${status}" -eq 0 ]
}

@test "key" {
    bkctld init test
    bkctld start test
    bkctld key test /root/bkctld.key.pub
    run cat /backup/jails/test/root/.ssh/authorized_keys
    [ "${status}" -eq 0 ]
    [ "${output}" = $(cat /root/bkctld.key.pub) ]
}

@test "port" {
    bkctld init test
    bkctld start test
    bkctld port test "${port}"
    run nc -vz 127.0.0.1 "${port}"
    [ "${status}" -eq 0 ]
}

@test "ip" {
    skip
}

@test "inc" {
    bkctld init test
    bkctld inc
    if [ "${inode}" -eq 256 ]; then
        run stat --format=%i "${INCDIR}/test/${date}"
        [ "${output}" -eq 256 ]
    else
        run test -d "${INCDIR}/test/${date}"
        [ "${status}" -eq 0 ]
    fi
}

@test "rm" {
    skip
}

@test "ssh" {
    bkctld init test
    bkctld start test
    bkctld port test "${port}"
    bkctld key test /root/bkctld.key.pub
    run ssh -p "${port}" -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 ls
    [ "$status" -eq 0 ]
}

@test "rsync" {
    bkctld init test
    bkctld start test
    bkctld port test "${port}"
    bkctld key test /root/bkctld.key.pub
    run rsync -a -e "ssh -p ${port} -i /root/bkctld.key -oStrictHostKeyChecking=no" /tmp/ root@127.0.0.1:/var/backup/
    [ "$status" -eq 0 ]
}
