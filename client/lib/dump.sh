#!/bin/bash
# shellcheck disable=SC2034,SC2317,SC2155

mysql_list_databases() {
    port=${1:-"3306"}

    mysql --defaults-extra-file=/etc/mysql/debian.cnf --port="${port}" --execute="show databases" --silent --skip-column-names \
        | grep --extended-regexp --invert-match "^(Database|information_schema|performance_schema|sys)"
}

### BEGIN Dump functions ####

#######################################################################
# Dump LDAP files (config, data, all)
#
# Arguments: <none>
#######################################################################
dump_ldap() {
    ## OpenLDAP : example with slapcat
    local dump_dir="${LOCAL_BACKUP_DIR}/ldap"
    rm -rf "${dump_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}"

    log "LOCAL_TASKS - start dump_ldap to ${dump_dir}"

    slapcat -n 0 -l "${dump_dir}/config.bak"
    slapcat -n 1 -l "${dump_dir}/data.bak"
    slapcat      -l "${dump_dir}/all.bak"

    log "LOCAL_TASKS - stop  dump_ldap"
}

#######################################################################
# Dump a single compressed file of all databases of an instance
#
# Arguments:
# --masterdata (default: <absent>)
# --port=[Integer] (default: 3306)
#######################################################################
dump_mysql_global() {
    local option_masterdata=""
    local option_port="3306"
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --masterdata)
                option_masterdata="--masterdata"
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-global-${option_port}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/mysqldump.err"
    local dump_file="${dump_dir}/mysqldump.sql.gz"
    log "LOCAL_TASKS - start ${dump_file}"

    ## Global all databases in one file
    declare -a options
    options=()
    options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
    options+=(--port="${option_port}")
    options+=(--opt)
    options+=(--force)
    options+=(--events)
    options+=(--hex-blob)
    options+=(--all-databases)
    if [ -n "${option_masterdata}" ]; then
        options+=("${option_masterdata}")
    fi

    mysqldump "${options[@]}" 2> "${error_file}" | gzip --best > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"

    ## Dump all grants (requires 'percona-toolkit' package)
    if command -v pt-show-grants > /dev/null; then
        local error_file="${errors_dir}/all_grants.err"
        local dump_file="${dump_dir}/all_grants.sql"
        log "LOCAL_TASKS - start ${dump_file}"

        declare -a options
        options=()
        options+=(--port "${option_port}")
        options+=(--flush)
        options+=(--no-header)

        pt-show-grants "${options[@]}" 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - pt-show-grants to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - stop  ${dump_file}"
    fi

    ## Dump all variables
    local error_file="${errors_dir}/variables.err"
    local dump_file="${dump_dir}/variables.txt"
    log "LOCAL_TASKS - start ${dump_file}"

    declare -a options
    options=()
    options+=(--port="${option_port}")
    options+=(--no-auto-rehash)
    options+=(-e "SHOW GLOBAL VARIABLES;")

    mysql "${options[@]}" 2> "${error_file}" > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - mysql 'show variables' returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"

    ## Schema only (no data) for each databases
    local error_file="${errors_dir}/mysqldump.schema.err"
    local dump_file="${dump_dir}/mysqldump.schema.sql"
    log "LOCAL_TASKS - start ${dump_file}"

    declare -a options
    options=()
    options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
    options+=(--port="${option_port}")
    options+=(--force)
    options+=(--no-data)
    options+=(--all-databases)

    mysqldump "${options[@]}" 2> "${error_file}" > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"
}

#######################################################################
# Dump a compressed file per database of an instance
#
# Arguments:
# --port=[Integer] (default: 3306)
#######################################################################
dump_mysql_per_base() {
    local option_port="3306"
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-per-base-${option_port}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    declare -a options
    options=()
    options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
    options+=(--port="${option_port}")
    options+=(--force)
    options+=(--events)
    options+=(--hex-blob)

    databases=$(mysql_list_databases "${option_port}")
    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.err"
        local dump_file="${dump_dir}/${database}.sql.gz"
        log "LOCAL_TASKS - start ${dump_file}"

        mysqldump "${options[@]}" "${database}" 2> "${error_file}" | gzip --best > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - stop  ${dump_file}"
    done

    ## Schema only (no data) for each databases
    databases=$(mysql_list_databases "${option_port}")
    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.schema.err"
        local dump_file="${dump_dir}/${database}.schema.sql"
        log "LOCAL_TASKS - start ${dump_file}"

        declare -a options
        options=()
        options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
        options+=(--port="${option_port}")
        options+=(--force)
        options+=(--no-data)
        options+=(--databases "${database}")

        mysqldump "${options[@]}" 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - stop  ${dump_file}"
    done
}

#######################################################################
# Dump "tabs style" separate schema/data for each database of an instance
#
# Arguments:
# --port=[Integer] (default: 3306)
#######################################################################
dump_mysql_tabs() {
    local option_port="3306"
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    databases=$(mysql_list_databases "${option_port}")
    for database in ${databases}; do
        local dump_dir="${LOCAL_BACKUP_DIR}/mysql-tabs-${option_port}/${database}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        # shellcheck disable=SC2174
        mkdir -p -m 700 "${dump_dir}" "${errors_dir}"
        chown -RL mysql "${dump_dir}"

        local error_file="${errors_dir}.err"
        log "LOCAL_TASKS - start ${dump_dir}"

        declare -a options
        options=()
        options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
        options+=(--port="${option_port}")
        options+=(--force)
        options+=(--quote-names)
        options+=(--opt)
        options+=(--events)
        options+=(--hex-blob)
        options+=(--skip-comments)
        options+=(--fields-enclosed-by='\"')
        options+=(--fields-terminated-by=',')
        options+=(--tab="${dump_dir}")
        options+=("${database}")

        mysqldump "${options[@]}" 2> "${error_file}"
 
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - mysqldump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - stop  ${dump_dir}"
    done
}

#######################################################################
# Dump a single file for all databases of an instance
# using a custom authentication, instead of /etc/mysql/debian.cnf
#
# Arguments:
# --port=[Integer] (default: 3306)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
#######################################################################
dump_mysql_instance() {
    local option_port=""
    local option_user=""
    local option_password=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-instance-${option_port}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    declare -a options
    options=()
    options+=(--port="${option_port}")
    options+=(--user="${option_user}")
    options+=(--password="${option_password}")
    options+=(--force)
    options+=(--opt)
    options+=(--all-databases)
    options+=(--events)
    options+=(--hex-blob)

    local error_file="${errors_dir}/mysql-global.err"
    local dump_file="${dump_dir}/mysql-global.sql.gz"
    log "LOCAL_TASKS - start ${dump_file}"

    mysqldump "${options[@]}" 2> "${error_file}" | gzip --best > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"
}

#######################################################################
# Dump a single file of all PostgreSQL databases
#
# Arguments: <none>
#######################################################################
dump_postgresql_global() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-global"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    ## example with pg_dumpall and with compression
    local error_file="${errors_dir}/pg_dumpall.err"
    local dump_file="${dump_dir}/pg_dumpall.sql.gz"
    log "LOCAL_TASKS - start ${dump_file}"

    (sudo -u postgres pg_dumpall) 2> "${error_file}" | gzip --best > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - pg_dumpall to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi

    log "LOCAL_TASKS - stop  ${dump_file}"

    ## example with pg_dumpall and without compression
    ## WARNING: you need space in ~postgres
    # local error_file="${errors_dir}/pg_dumpall.err"
    # local dump_file="${dump_dir}/pg_dumpall.sql"
    # log "LOCAL_TASKS - start ${dump_file}"
    # 
    # (su - postgres -c "pg_dumpall > ~/pg.dump.bak") 2> "${error_file}"
    # mv ~postgres/pg.dump.bak "${dump_file}"
    # 
    # log "LOCAL_TASKS - stop  ${dump_file}"
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
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    (
        # shellcheck disable=SC2164
        cd /var/lib/postgresql
        databases=$(sudo -u postgres psql -U postgres -lt | awk -F\| '{print $1}' | grep -v "template.*")
        for database in ${databases} ; do
            local error_file="${errors_dir}/${database}.err"
            local dump_file="${dump_dir}/${database}.sql.gz"
            log "LOCAL_TASKS - start ${dump_file}"

            (sudo -u postgres /usr/bin/pg_dump --create -U postgres -d "${database}") 2> "${error_file}" | gzip --best > "${dump_file}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi
            log "LOCAL_TASKS - stop  ${dump_file}"
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
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/pg-backup.err"
    local dump_file="${dump_dir}/pg-backup.tar"
    log "LOCAL_TASKS - start ${dump_file}"

    ## example with all tables from MYBASE excepts TABLE1 and TABLE2
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -t 'TABLE1' -t 'TABLE2' MYBASE 2> "${error_file}"

    ## example with only TABLE1 and TABLE2 from MYBASE
    # pg_dump -p 5432 -h 127.0.0.1 -U USER --clean -F t --inserts -f "${dump_file}" -T 'TABLE1' -T 'TABLE2' MYBASE 2> "${error_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"
}

#######################################################################
# Copy dump file of Redis instances
#
# Arguments:
# --instances=[Integer] (default: all)
#######################################################################
dump_redis() {
    all_instances=$(find /var/lib/ -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' -name 'redis*')

    local option_instances=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --instances)
                # instances options, with key and value separated by space
                if [ -n "$2" ]; then
                    if [ "${2}" == "all" ]; then
                        read -a option_instances <<< "${all_instances}"
                    else
                        IFS="," read -a option_instances <<< "${2}"
                    fi
                    shift
                else
                    log_error "LOCAL_TASKS - '--instances' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --instances=?*)
                # instances options, with key and value separated by =
                if [ "${1#*=}" == "all" ]; then
                    read -a option_instances <<< "${all_instances}"
                else
                    IFS="," read -a option_instances <<< "${1#*=}"
                fi
                ;;
            --instances=)
                # instances options, without value
                log_error "LOCAL_TASKS - '--instances' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done
    
    for instance in "${option_instances[@]}"; do
        name=$(basename "${instance}")
        local dump_dir="${LOCAL_BACKUP_DIR}/${name}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        # shellcheck disable=SC2174
        mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

        if [ -f "${instance}/dump.rdb" ]; then
            local error_file="${errors_dir}/${instance}.err"
            log "LOCAL_TASKS - start ${dump_dir}"

            cp -a "${instance}/dump.rdb" "${dump_dir}/dump.rdb" 2> "${error_file}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - cp ${instance}/dump.rdb to ${dump_dir} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi

            gzip "${dump_dir}/dump.rdb"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - gzip ${dump_dir}/dump.rdb returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi

            log "LOCAL_TASKS - stop  ${dump_dir}"
        else
            log_error "LOCAL_TASKS - '${instance}/dump.rdb' not found."
        fi
    done
}

#######################################################################
# Dump all collections of a MongoDB database
# using a custom authentication, instead of /etc/mysql/debian.cnf
#
# Arguments:
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
#######################################################################
dump_mongodb() {
    ## don't forget to create use with read-only access
    ## > use admin
    ## > db.createUser( { user: "mongobackup", pwd: "PASS", roles: [ "backup", ] } )

    local dump_dir="${LOCAL_BACKUP_DIR}/mongodump"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    log "LOCAL_TASKS - start ${dump_dir}"

    local option_user=""
    local option_password=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    declare -a options
    options=()
    options+=(--username="${option_user}")
    options+=(--password="${option_password}")
    options+=(--out="${dump_dir}/")

    mongodump "${options[@]}" 2> "${error_file}" > /dev/null

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - mongodump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_dir}"
}

#######################################################################
# Dump MegaCLI configuration
#
# Arguments: <none>
#######################################################################
dump_megacli_config() {
    local dump_dir="${LOCAL_BACKUP_DIR}/megacli"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local dump_file="${dump_dir}/megacli.cfg"
    local error_file="${errors_dir}/megacli.err"
    log "LOCAL_TASKS - start ${dump_file}"

    megacli -CfgSave -f "${dump_file}" -a0 2> "${error_file}" > /dev/null

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - megacli to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"
}

#######################################################################
# Save some traceroute/mtr results
#
# Arguments:
# --targets=[IP,HOST] (default: <none>)
#######################################################################
dump_traceroute() {
    local dump_dir="${LOCAL_BACKUP_DIR}/traceroute"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local option_targets=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --targets)
                # targets options, with key and value separated by space
                if [ -n "$2" ]; then
                    IFS="," read -a option_targets <<< "${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--targets' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --targets=?*)
                # targets options, with key and value separated by =
                IFS="," read -a option_targets <<< "${1#*=}"
                ;;
            --targets=)
                # targets options, without value
                log_error "LOCAL_TASKS - '--targets' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    mtr_bin=$(command -v mtr)
    if [ -n "${mtr_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/mtr-${target}"
            log "LOCAL_TASKS - start ${dump_file}"

            ${mtr_bin} -r "${target}" > "${dump_file}"

            log "LOCAL_TASKS - stop  ${dump_file}"
        done
    fi

    traceroute_bin=$(command -v traceroute)
    if [ -n "${traceroute_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/traceroute-${target}"
            log "LOCAL_TASKS - start ${dump_file}"

            ${traceroute_bin} -n "${target}" > "${dump_file}" 2>&1

            log "LOCAL_TASKS - stop  ${dump_file}"
        done
    fi
}

#######################################################################
# Save many system information, using dump_server_state
#
# Arguments:
# any option for dump-server-state (except --dump-dir) is usable
# (default: --all)
#######################################################################
dump_server_state() {
    local dump_dir="${LOCAL_BACKUP_DIR}/server-state"
    rm -rf "${dump_dir}"
    # Do not create the directory
    # shellcheck disable=SC2174
    # mkdir -p -m 700 "${dump_dir}"

    log "LOCAL_TASKS - start ${dump_dir}"

    # pass all options
    read -a options <<< "${@}"
    # if no option is given, use "--all" as fallback
    if [ ${#options[@]} -le 0 ]; then
        options=(--all)
    fi
    # add "--dump-dir" in case it is missing (as it should)
    options+=(--dump-dir "${dump_dir}")

    dump_server_state_bin=$(command -v dump-server-state)
    if [ -z "${dump_server_state_bin}" ]; then
        log_error "LOCAL_TASKS - dump-server-state is missing"
        rc=1
    else
        ${dump_server_state_bin} "${options[@]}"
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - dump-server-state returned an error ${last_rc}, check ${dump_dir}"
            GLOBAL_RC=${E_DUMPFAILED}
        fi
    fi
    log "LOCAL_TASKS - stop  ${dump_dir}"
}

#######################################################################
# Save RabbitMQ data
# 
# Arguments: <none>
# 
# Warning: This has been poorly tested
#######################################################################
dump_rabbitmq() {
    local dump_dir="${LOCAL_BACKUP_DIR}/rabbitmq"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    local dump_file="${dump_dir}/config"
    log "LOCAL_TASKS - start ${dump_file}"

    rabbitmqadmin export "${dump_file}" 2> "${error_file}" >> "${LOGFILE}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - pg_dump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"
}

#######################################################################
# Save Files ACL on various partitions.
# 
# Arguments: <none>
#######################################################################
dump_facl() {
    local dump_dir="${LOCAL_BACKUP_DIR}/facl"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    log "LOCAL_TASKS - start ${dump_dir}"

    getfacl -R /etc  > "${dump_dir}/etc.txt"
    getfacl -R /home > "${dump_dir}/home.txt"
    getfacl -R /usr  > "${dump_dir}/usr.txt"
    getfacl -R /var  > "${dump_dir}/var.txt"

    log "LOCAL_TASKS - stop  ${dump_dir}"
}

#######################################################################
# Snapshot Elasticsearch data (single-node cluster)
# 
# Arguments:
# --protocol=[String] (default: http)
# --host=[String] (default: localhost)
# --port=[Integer] (default: 9200)
# --user=[String] (default: <none>)
# --password=[String] (default: <none>)
# --repository=[String] (default: snaprepo)
# --snapshot=[String] (default: snapshot.daily)
#######################################################################
dump_elasticsearch_snapshot_singlenode() {
    log "LOCAL_TASKS - start dump_elasticsearch_snapshot_singlenode"

    local option_protocol="http"
    local option_host="localhost"
    local option_port="9200"
    local option_user=""
    local option_password=""
    local option_repository="snaprepo"
    local option_snapshot="snapshot.daily"
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --protocol)
                # protocol options, with value separated by space
                if [ -n "$2" ]; then
                    option_protocol="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--protocol' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --protocol=?*)
                # protocol options, with value separated by =
                option_protocol="${1#*=}"
                ;;
            --protocol=)
                # protocol options, without value
                log_error "LOCAL_TASKS - '--protocol' requires a non-empty option argument."
                exit 1
                ;;
            --host)
                # host options, with value separated by space
                if [ -n "$2" ]; then
                    option_host="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--host' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --host=?*)
                # host options, with value separated by =
                option_host="${1#*=}"
                ;;
            --host=)
                # host options, without value
                log_error "LOCAL_TASKS - '--host' requires a non-empty option argument."
                exit 1
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                exit 1
                ;;
            --repository)
                # repository options, with value separated by space
                if [ -n "$2" ]; then
                    option_repository="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--repository' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --repository=?*)
                # repository options, with value separated by =
                option_repository="${1#*=}"
                ;;
            --repository=)
                # repository options, without value
                log_error "LOCAL_TASKS - '--repository' requires a non-empty option argument."
                exit 1
                ;;
            --snapshot)
                # snapshot options, with value separated by space
                if [ -n "$2" ]; then
                    option_snapshot="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--snapshot' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --snapshot=?*)
                # snapshot options, with value separated by =
                option_snapshot="${1#*=}"
                ;;
            --snapshot=)
                # snapshot options, without value
                log_error "LOCAL_TASKS - '--snapshot' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    ## Take a snapshot as a backup.
    ## Warning: You need to have a path.repo configured.
    ## See: https://wiki.evolix.org/HowtoElasticsearch#snapshots-et-sauvegardes

    local base_url="${option_protocol}://${option_host}:${option_port}"
    local snapshot_url="${base_url}/_snapshot/${option_repository}/${option_snapshot}"

    if [ -n "${option_user}" ] || [ -n "${option_password}" ]; then
        local option_auth="--user ${option_user}:${option_password}"
    else
        local option_auth=""
    fi

    curl -s -XDELETE "${option_auth}" "${snapshot_url}" >> "${LOGFILE}"
    curl -s -XPUT "${option_auth}" "${snapshot_url}?wait_for_completion=true" >> "${LOGFILE}"

    # Clustered version here
    # It basically the same thing except that you need to check that NFS is mounted
    # if ss | grep ':nfs' | grep -q 'ip\.add\.res\.s1' && ss | grep ':nfs' | grep -q 'ip\.add\.res\.s2'
    # then
    #     curl -s -XDELETE "${option_auth}" "${snapshot_url}" >> "${LOGFILE}"
    #     curl -s -XPUT "${option_auth}" "${snapshot_url}?wait_for_completion=true" >> "${LOGFILE}"
    # else
    #     echo 'Cannot make a snapshot of elasticsearch, at least one node is not mounting the repository.'
    # fi

    log "LOCAL_TASKS - stop  dump_elasticsearch_snapshot_singlenode"
}

#######################################################################
# Snapshot Elasticsearch data (multi-node cluster)
# 
# Arguments:
# --protocol=[String] (default: http)
# --host=[String] (default: localhost)
# --port=[Integer] (default: 9200)
# --user=[String] (default: <none>)
# --password=[String] (default: <none>)
# --repository=[String] (default: snaprepo)
# --snapshot=[String] (default: snapshot.daily)
# --nfs-server=[IP|HOST] (default: <none>)
#######################################################################
dump_elasticsearch_snapshot_multinode() {
    log "LOCAL_TASKS - start dump_elasticsearch_snapshot_multinode"

    local option_protocol="http"
    local option_host="localhost"
    local option_port="9200"
    local option_user=""
    local option_password=""
    local option_repository="snaprepo"
    local option_snapshot="snapshot.daily"
    local option_nfs_server=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --protocol)
                # protocol options, with value separated by space
                if [ -n "$2" ]; then
                    option_protocol="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--protocol' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --protocol=?*)
                # protocol options, with value separated by =
                option_protocol="${1#*=}"
                ;;
            --protocol=)
                # protocol options, without value
                log_error "LOCAL_TASKS - '--protocol' requires a non-empty option argument."
                exit 1
                ;;
            --host)
                # host options, with value separated by space
                if [ -n "$2" ]; then
                    option_host="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--host' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --host=?*)
                # host options, with value separated by =
                option_host="${1#*=}"
                ;;
            --host=)
                # host options, without value
                log_error "LOCAL_TASKS - '--host' requires a non-empty option argument."
                exit 1
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - '--port' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - '--password' requires a non-empty option argument."
                exit 1
                ;;
            --repository)
                # repository options, with value separated by space
                if [ -n "$2" ]; then
                    option_repository="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--repository' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --repository=?*)
                # repository options, with value separated by =
                option_repository="${1#*=}"
                ;;
            --repository=)
                # repository options, without value
                log_error "LOCAL_TASKS - '--repository' requires a non-empty option argument."
                exit 1
                ;;
            --snapshot)
                # snapshot options, with value separated by space
                if [ -n "$2" ]; then
                    option_snapshot="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--snapshot' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --snapshot=?*)
                # snapshot options, with value separated by =
                option_snapshot="${1#*=}"
                ;;
            --snapshot=)
                # snapshot options, without value
                log_error "LOCAL_TASKS - '--snapshot' requires a non-empty option argument."
                exit 1
                ;;
            --nfs-server)
                # nfs-server options, with value separated by space
                if [ -n "$2" ]; then
                    option_nfs_server="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - '--nfs-server' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --nfs-server=?*)
                # nfs-server options, with value separated by =
                option_nfs_server="${1#*=}"
                ;;
            --nfs-server=)
                # nfs-server options, without value
                log_error "LOCAL_TASKS - '--nfs-server' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    ## Take a snapshot as a backup.
    ## Warning: You need to have a path.repo configured.
    ## See: https://wiki.evolix.org/HowtoElasticsearch#snapshots-et-sauvegardes

    local base_url="${option_protocol}://${option_host}:${option_port}"
    local snapshot_url="${base_url}/_snapshot/${option_repository}/${option_snapshot}"

    if [ -n "${option_user}" ] || [ -n "${option_password}" ]; then
        local option_auth="--user ${option_user}:${option_password}"
    else
        local option_auth=""
    fi

    # Clustered version here
    # It basically the same thing except that you need to check that NFS is mounted
    if ss | grep ':nfs' | grep -q -F "${option_nfs_server}"; then
        curl -s -XDELETE "${option_auth}" "${snapshot_url}" >> "${LOGFILE}"
        curl -s -XPUT "${option_auth}" "${snapshot_url}?wait_for_completion=true" >> "${LOGFILE}"
    else
        echo 'Cannot make a snapshot of elasticsearch, at least one node is not mounting the repository.'
    fi

    log "LOCAL_TASKS - stop  dump_elasticsearch_snapshot_multinode"
}