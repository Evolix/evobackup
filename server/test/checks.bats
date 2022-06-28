#!/usr/bin/env bats
# shellcheck disable=SC1089,SC1083,SC2154

load test_helper

@test "Check jails OK" {
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "0" "$status"
}

@test "Check jails OK for default values" {
    touch "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a freshly connected jail should be "ok"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "0" "$status"
}

@test "Check jails WARNING for default values" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 2 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "1" "$status"
}

@test "Check jails CRITICAL for default values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 3 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "2" "$status"
}

@test "Check jails OK for custom values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=120
WARNING=96
OUT
    # With custom values (5 days critical, 4 days warning),
    # a 3 days old jail should be "ok"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "0" "$status"
}

@test "Check jails WARNING for custom values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=96
WARNING=48
OUT
    # With custom values (4 days critical, 3 days warning),
    # a 3 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "1" "$status"
}

@test "Check jails CRITICAL for custom values" {
    lastlog_date=$(date -d -10days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=96
WARNING=48
OUT
    # With custom values (4 days critical, 3 days warning),
    # a 10 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "2" "$status"
}

@test "Check jails OK for disabled WARNING" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
WARNING=0
OUT
    # With custom values (warning disabled, default critical),
    # a 2 days old jail should still be "ok"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "0" "$status"
}

@test "Check jails WARNING for disabled CRITICAL" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=0
OUT
    # With custom values (critical disabled, default warning),
    # a 3 days old jail should only be "warning"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "1" "$status"
}

@test "Custom jails values are parsed with only integers after equal" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=0 # foo
OUT
    # With custom values (critical disabled, default warning),
    # a 3 days old jail should only be "warning"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "1" "$status"
}

@test "Commented custom values are ignored" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
# CRITICAL=0
OUT
    # With commented custom values (critical disabled),
    # a 3 days old jail should still be "critical"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "2" "$status"
}

@test "Invalid custom values are ignored" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=foo
OUT
    # With commented custom values (critical disabled),
    # a 3 days old jail should still be "critical"
    run /usr/lib/bkctld/bkctld-check-jails
    assert_equal "2" "$status"
}

@test "Check setup WARNING if firewall rules are not sourced" {
    /usr/lib/bkctld/bkctld-start ${JAILNAME}

    mkdir --parents /etc/minifirewall.d/
    firewall_rules_file="/etc/minifirewall.d/bkctld"
    set_variable "/etc/default/bkctld" "FIREWALL_RULES" "${firewall_rules_file}"
    echo "" > "${firewall_rules_file}"

    # Without sourcing
    echo "" > "/etc/default/minifirewall"
    # … the check should be "warning"
    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "1" "$status"
}

@test "Check setup OK if firewall rules are sourced" {
    /usr/lib/bkctld/bkctld-start ${JAILNAME}

    mkdir --parents /etc/minifirewall.d/
    firewall_rules_file="/etc/minifirewall.d/bkctld"
    set_variable "/etc/default/bkctld" "FIREWALL_RULES" "${firewall_rules_file}"
    echo "" > "${firewall_rules_file}"

    # Sourcing file with '.'
    echo ". ${firewall_rules_file}" > "/etc/default/minifirewall"
    # … the check should be "ok"
    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "0" "$status"

    # Sourcing file with 'source'
    echo "source ${firewall_rules_file}" > "/etc/default/minifirewall"
    # … the check should be "ok"
    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "0" "$status"
}

@test "Check setup CRITICAL if jail is stopped" {
    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "2" "$status"
}

@test "Check setup OK if all jails are started" {
    /usr/lib/bkctld/bkctld-start ${JAILNAME}

    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "0" "$status"
}

@test "Check setup OK if jail is supposed to be stopped" {
    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
EXPECTED_STATE=OFF
OUT

    run /usr/lib/bkctld/bkctld-check-setup
    assert_equal "0" "$status"
}

@test "Check setup CRITICAL if backup partition is not mounted" {
    umount --force /backup

    run /usr/lib/bkctld/bkctld-check-setup

    mount /dev/vdb /backup

    assert_equal "2" "$status"
}

@test "Check setup CRITICAL if backup partition is read-only" {
    mount -o remount,ro /backup

    run /usr/lib/bkctld/bkctld-check-setup

    mount -o remount,rw /backup

    assert_equal "2" "$status"
}

@test "Check-last-incs OK if jail is present" {
    /usr/lib/bkctld/bkctld-inc

    run /usr/lib/bkctld/bkctld-check-last-incs
    assert_equal "0" "$status"
}

@test "Check-last-incs Error if jail is missing" {

    run /usr/lib/bkctld/bkctld-check-last-incs
    assert_equal "1" "$status"
}

@test "Check-incs OK" {
    /usr/lib/bkctld/bkctld-inc

    run /usr/lib/bkctld/bkctld-check-incs
    assert_equal "0" "$status"
}

@test "Check-incs doesn't fail without incs_policy file" {
    # Delete all possible incs polixy files
    rm -f /etc/evobackup/${JAILNAME}
    rm -rf /etc/evobackup/${JAILNAME}.d/incs_policy

    # Run bkctld-check-incs and store stderr in a file
    local stderrPath="${BATS_TMPDIR}/${BATS_TEST_NAME}.stderr"
    /usr/lib/bkctld/bkctld-check-incs 2> ${stderrPath}

    # Verify if 
    run grep -E "^stat:" ${stderrPath}
    assert_failure
}
# TODO: write many more tests for bkctld-check-incs
