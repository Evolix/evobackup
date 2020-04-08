#!/usr/bin/env bats

load test_helper

@test "Check OK for default values" {
    touch "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a freshly connected jail should be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "0" "$status"
}

@test "Check WARNING for default values" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 2 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "1" "$status"
}

@test "Check CRITICAL for default values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"
    # With default values (2 days critical, 1 day warning),
    # a 3 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "2" "$status"
}

@test "Check OK for custom values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=120
WARNING=96
OUT
    # With custom values (5 days critical, 4 days warning),
    # a 3 days old jail should be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "0" "$status"
}

@test "Check WARNING for custom values" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=96
WARNING=48
OUT
    # With custom values (4 days critical, 3 days warning),
    # a 3 days old jail should be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "1" "$status"
}

@test "Check CRITICAL for custom values" {
    lastlog_date=$(date -d -10days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=96
WARNING=48
OUT
    # With custom values (4 days critical, 3 days warning),
    # a 10 days old jail should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "2" "$status"
}

@test "Check OK for disabled WARNING" {
    lastlog_date=$(date -d -2days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
WARNING=0
OUT
    # With custom values (warning disabled, default critical),
    # a 2 days old jail should still be "ok"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "0" "$status"
}

@test "Check WARNING for disabled CRITICAL" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=0
OUT
    # With custom values (critical disabled, default warning),
    # a 3 days old jail should only be "warning"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "1" "$status"
}

@test "Custom values are parsed with only integers after equal" {
    lastlog_date=$(date -d -3days --iso-8601=seconds)
    touch --date="${lastlog_date}" "${JAILPATH}/var/log/lastlog"

    cat > "/etc/evobackup/${JAILNAME}.d/check_policy" <<OUT
CRITICAL=0 # foo
OUT
    # With custom values (critical disabled, default warning),
    # a 3 days old jail should only be "warning"
    run /usr/lib/bkctld/bkctld-check
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
    run /usr/lib/bkctld/bkctld-check
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
    run /usr/lib/bkctld/bkctld-check
    assert_equal "2" "$status"
}

@test "Check CRITICAL if firewall rules are not sourced" {
    firewall_rules_file="/etc/firewall.rc.jails"
    set_variable "/etc/default/bkctld" "FIREWALL_RULES" "${firewall_rules_file}"
    echo "" > "${firewall_rules_file}"

    # Without sourcing
    echo "" > "/etc/default/minifirewall"
    # … the check should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "2" "$status"
}

@test "Check OK if firewall rules are sourced" {
    firewall_rules_file="/etc/firewall.rc.jails"
    set_variable "/etc/default/bkctld" "FIREWALL_RULES" "${firewall_rules_file}"
    echo "" > "${firewall_rules_file}"

    # Sourcing file with '.'
    echo ". ${firewall_rules_file}" > "/etc/default/minifirewall"
    # … the check should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "0" "$status"

    # Sourcing file with 'source'
    echo "source ${firewall_rules_file}" > "/etc/default/minifirewall"
    # … the check should be "critical"
    run /usr/lib/bkctld/bkctld-check
    assert_equal "0" "$status"
}
