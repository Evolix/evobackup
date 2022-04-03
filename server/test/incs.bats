#!/usr/bin/env bats
# shellcheck disable=SC1089,SC1083,SC2154

load test_helper


@test "Inc policy after jail init" {
    # An incs_policy file should exist
    run test -e "${CONFDIR}/${JAILNAME}.d/incs_policy"
    [ "${status}" -eq 0 ]
}

@test "Normal inc creation" {
    /usr/lib/bkctld/bkctld-inc

    if is_btrfs "/backup"; then
        # On a btrfs filesystem, the inc should be a btrfs volume
        run is_btrfs "${INCSPATH}/${INC_NAME}"
        assert_success
    else
        # On an ext4 filesystem, the inc should be a regular directory
        run test -d "${INCSPATH}/${INC_NAME}"
        assert_success
    fi
}

@test "Normal inc creation (with old incs policy)" {
    mv "${CONFDIR}/${JAILNAME}.d/incs_policy" "${CONFDIR}/${JAILNAME}"

    /usr/lib/bkctld/bkctld-inc

    if is_btrfs "/backup"; then
        # On a btrfs filesystem, the inc should be a btrfs volume
        run is_btrfs "${INCSPATH}/${INC_NAME}"
        assert_success
    else
        # On an ext4 filesystem, the inc should be a regular directory
        run test -d "${INCSPATH}/${INC_NAME}"
        assert_success
    fi
}

@test "No inc creation without inc policy" {
    # Remove inc_policy
    rm -f "${CONFDIR}/${JAILNAME}.d/incs_policy"
    # … and old file
    rm -f "${CONFDIR}/${JAILNAME}"

    /usr/lib/bkctld/bkctld-inc

    run test -d "${INCSPATH}/${INC_NAME}"
    assert_failure
}

@test "Recent inc is kept after 'rm'" {
    # Setup simple incs policy
    echo "+%Y-%m-%d.-0day" > "${CONFDIR}/${JAILNAME}.d/incs_policy"

    # Prepare an inc older than the policy
    recent_inc_path="${INCSPATH}/${INC_NAME}"

    # Create the inc, then run 'rm'
    /usr/lib/bkctld/bkctld-inc
    /usr/lib/bkctld/bkctld-rm

    # Recent inc should be present
    run test -d "${recent_inc_path}"
    assert_success
}

@test "Older inc is removed by 'rm'" {
    # Setup simple incs policy
    echo "+%Y-%m-%d.-0day" > "${CONFDIR}/${JAILNAME}.d/incs_policy"

    # Prepare an inc older than the policy
    recent_inc_path="${INCSPATH}/${INC_NAME}"
    older_inc_name=$(date -d -1days +"%Y-%m-%d-%H")
    older_inc_path="${INCSPATH}/${older_inc_name}"

    # Create the inc, rename it to make it older, then run 'rm'
    /usr/lib/bkctld/bkctld-inc
    mv "${recent_inc_path}" "${older_inc_path}"
    /usr/lib/bkctld/bkctld-rm

    # Older inc should be removed
    run test -d "${older_inc_path}"
    assert_failure
}

@test "All incs are removed by 'rm' with empty inc policy" {
    # Setup empty incs policy
    echo "" > "${CONFDIR}/${JAILNAME}.d/incs_policy"
    inc_path="${INCSPATH}/${INC_NAME}"

    # Create the inc
    /usr/lib/bkctld/bkctld-inc
    # Inc should be removed
    run test -d "${inc_path}"
    assert_success

    # Remove incs
    /usr/lib/bkctld/bkctld-rm
    # Inc should be removed
    run test -d "${inc_path}"
    assert_failure
}

@test "empty inc directory are removed" {
    # Create an inc
    /usr/lib/bkctld/bkctld-inc
    # no inc should be kept
    echo '' > "${CONFDIR}/${JAILNAME}.d/incs_policy"

    # The inc directory is present
    run test -d "${INCSPATH}"
    assert_success

    /usr/lib/bkctld/bkctld-rm

    # The inc directory is absent
    run test -d "${INCSPATH}"
    assert_failure
}

@test "BTRFS based inc can be unlock with complex pattern" {
    if is_btrfs "/backup"; then
        # Prepare an inc older than the policy
        recent_inc_path="${INCSPATH}/${INC_NAME}"
        older_inc_name=$(date -d -1month +"%Y-%m-%d-%H")
        older_inc_path="${INCSPATH}/${older_inc_name}"

        # Create the inc, rename it to make it older, then run 'rm'
        /usr/lib/bkctld/bkctld-inc
        mv "${recent_inc_path}" "${older_inc_path}"
        # run 'inc' again to remake today's inc
        /usr/lib/bkctld/bkctld-inc

        # inc should be locked
        run touch "${older_inc_path}/var/log/lastlog"
        assert_failure

        # unlock inc
        pattern="${JAILNAME}/$(date -d -1month +"%Y-%m-*")"
        bkctld inc-unlock "${pattern}"

        # inc should be unlocked
        run touch "${older_inc_path}/var/log/lastlog"
        assert_success

        # other inc should still be locked
        run touch "${recent_inc_path}/var/log/lastlog"
        assert_failure
    else
        # On an ext4 filesystem it's always true
        run true
        assert_success
    fi
}

@test "BTRFS based inc can be unlock with jail name" {
    if is_btrfs "/backup"; then
        # Prepare an inc older than the policy
        recent_inc_path="${INCSPATH}/${INC_NAME}"
        older_inc_name=$(date -d -1month +"%Y-%m-%d-%H")
        older_inc_path="${INCSPATH}/${older_inc_name}"

        # Create the inc, rename it to make it older, then run 'rm'
        /usr/lib/bkctld/bkctld-inc
        mv "${recent_inc_path}" "${older_inc_path}"
        # run 'inc' again to remake today's inc
        /usr/lib/bkctld/bkctld-inc

        # incs should be locked
        run touch "${recent_inc_path}/var/log/lastlog"
        assert_failure
        run touch "${older_inc_path}/var/log/lastlog"
        assert_failure

        # unlock incs
        pattern="${JAILNAME}"
        bkctld inc-unlock "${pattern}"

        # incs should be unlocked
        run touch "${recent_inc_path}/var/log/lastlog"
        assert_success
        run touch "${older_inc_path}/var/log/lastlog"
        assert_success
    else
        # On an ext4 filesystem it's always true
        run true
        assert_success
    fi
}

@test "BTRFS based inc can be unlock with 'all' pattern" {
    if is_btrfs "/backup"; then
        # Prepare an inc older than the policy
        recent_inc_path="${INCSPATH}/${INC_NAME}"
        older_inc_name=$(date -d -1month +"%Y-%m-%d-%H")
        older_inc_path="${INCSPATH}/${older_inc_name}"

        # Create the inc, rename it to make it older, then run 'rm'
        /usr/lib/bkctld/bkctld-inc
        mv "${recent_inc_path}" "${older_inc_path}"
        # run 'inc' again to remake today's inc
        /usr/lib/bkctld/bkctld-inc

        # incs should be locked
        run touch "${recent_inc_path}/var/log/lastlog"
        assert_failure
        run touch "${older_inc_path}/var/log/lastlog"
        assert_failure

        # unlock incs
        pattern="all"
        bkctld inc-unlock "${pattern}"

        # incs should be unlocked
        run touch "${recent_inc_path}/var/log/lastlog"
        assert_success
        run touch "${older_inc_path}/var/log/lastlog"
        assert_success
    else
        # On an ext4 filesystem it's always true
        run true
        assert_success
    fi
}

# TODO: add many tests for incs (creation and removal)
