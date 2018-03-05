#!/usr/bin/env bats

setup() {
    rm -f /root/bkctld.key* && ssh-keygen -t rsa -N "" -f /root/bkctld.key -q
    bkctld init test
    bkctld key test /root/bkctld.key.pub
    bkctld start test
}

teardown() {
    bkctld remove test
}

@test "simple ssh" {
    run ssh -p 2223 -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 lastlog -u root
    [ "$status" -eq 0 ]
}

@test "rsync" {
    run rsync -a -e "ssh -p 2223 -i /root/bkctld.key -oStrictHostKeyChecking=no" /tmp/ root@127.0.0.1:/var/backup/
    [ "$status" -eq 0 ]
}
