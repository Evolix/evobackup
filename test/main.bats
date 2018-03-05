#!/usr/bin/env bats

setup() {
    port=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    rm -f /root/bkctld.key* && ssh-keygen -t rsa -N "" -f /root/bkctld.key -q
    bkctld init test
    bkctld port test "${port}"
    bkctld key test /root/bkctld.key.pub
    bkctld start test
    bpid=$(cat /backup/jails/test/run/sshd.pid)
    bkctld restart test
    apid=$(cat /backup/jails/test/run/sshd.pid)
    bkctld inc
}

teardown() {
    bkctld remove test
}

@test "port" {
    run nc -vz 127.0.0.1 "${port}"
    [ "$status" -eq 0 ]
}

@test "key" {
    run cat /backup/jails/test/root/.ssh/authorized_keys
    [ "$status" -eq 0 ]
    [ "$output" = $(cat /root/bkctld.key.pub) ]
}

@test "ssh" {
    run ssh -p "${port}" -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 ls
    [ "$status" -eq 0 ]
}

@test "rsync" {
    run rsync -a -e "ssh -p ${port} -i /root/bkctld.key -oStrictHostKeyChecking=no" /tmp/ root@127.0.0.1:/var/backup/
    [ "$status" -eq 0 ]
}

@test "restart" {
    [ "${bpid}" -ne "${apid}" ]
}

@test "inc" {
    run ls /backup/incs/test/*
    [ "$status" -eq 0 ]
}
