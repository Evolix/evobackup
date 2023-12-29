#!/bin/bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Dump a single file of all PostgreSQL databases
#
# Arguments: <none>
#######################################################################
dump_postgresql_global() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-global"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## example with pg_dumpall and with compression
    local error_file="${errors_dir}/pg_dumpall.err"
    local dump_file="${dump_dir}/pg_dumpall.sql.gz"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    (sudo -u postgres pg_dumpall) 2> "${error_file}" | gzip --best > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dumpall to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"

    ## example with pg_dumpall and without compression
    ## WARNING: you need space in ~postgres
    # local error_file="${errors_dir}/pg_dumpall.err"
    # local dump_file="${dump_dir}/pg_dumpall.sql"
    # log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"
    # 
    # (su - postgres -c "pg_dumpall > ~/pg.dump.bak") 2> "${error_file}"
    # mv ~postgres/pg.dump.bak "${dump_file}"
    # 
    # log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}

#######################################################################
# Dump a compressed file per database
#
# Arguments: <none>
#######################################################################
dump_postgresql_per_base() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-per-base"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    (
        # shellcheck disable=SC2164
        cd /var/lib/postgresql
        databases=$(sudo -u postgres psql -U postgres -lt | awk -F\| '{print $1}' | grep -v "template.*")
        for database in ${databases} ; do
            local error_file="${errors_dir}/${database}.err"
            local dump_file="${dump_dir}/${database}.sql.gz"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            (sudo -u postgres /usr/bin/pg_dump --create -U postgres -d "${database}") 2> "${error_file}" | gzip --best > "${dump_file}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi
            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
        done
    )
}

#######################################################################
# Dump a compressed file per database
#
# Arguments: <none>
#
# TODO: add arguments to include/exclude tables
#######################################################################
dump_postgresql_filtered() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-filtered"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/pg-backup.err"
    local dump_file="${dump_dir}/pg-backup.tar"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    ## example with all tables from MYBASE excepts TABLE1 and TABLE2
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -t 'TABLE1' -t 'TABLE2' MYBASE 2> "${error_file}"

    ## example with only TABLE1 and TABLE2 from MYBASE
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -T 'TABLE1' -T 'TABLE2' MYBASE 2> "${error_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}
