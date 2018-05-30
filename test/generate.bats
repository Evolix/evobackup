#!/usr/bin/env bats

@test "generate" {
    jails="test0 test1 test2 test3 test4 test5"
    for jail in ${jails}; do
        bkctld init "${jail}"
        random=$(od -An -N4 -i < /dev/urandom|grep -Eo "[0-9]{2}$")
        date=$(date -d "${random} hour ago")
        touch -m --date="${date}" "/backup/jails/${jail}/var/log/lastlog"
    done
}
