#!/bin/bash
# shellcheck disable=SC2034,SC2317,SC2155

mysql_list_databases() {
    port=${1:-"3306"}

    mysql --defaults-extra-file=/etc/mysql/debian.cnf --port="${port}" --execute="show databases" --silent --skip-column-names \
        | grep --extended-regexp --invert-match "^(Database|information_schema|performance_schema|sys)"
}

#######################################################################
# Dump complete summary of an instance (using pt-mysql-summary)
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_summary() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                exit 1
                ;;
            --dump-label)
                # dump-label options, with value separated by space
                if [ -n "$2" ]; then
                    option_dump_label="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --dump-label=?*)
                # dump-label options, with value separated by =
                option_dump_label="${1#*=}"
                ;;
            --dump-label=)
                # dump-label options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unkwnown option (ignored): '${1}'"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    # DO NOT REMOVE EXISTING DIRECTORIES
    # rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## Dump all grants (requires 'percona-toolkit' package)
    if command -v pt-mysql-summary > /dev/null; then
        local error_file="${errors_dir}/mysql-summary.err"
        local dump_file="${dump_dir}/mysql-summary.out"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        ## Connection options
        declare -a connect_options
        connect_options=()
        if [ -n "${option_defaults_file}" ]; then
            connect_options+=(--defaults-file="${option_defaults_file}")
        fi
        if [ -n "${option_defaults_extra_file}" ]; then
            connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
        fi
        if [ -n "${option_defaults_group_suffix}" ]; then
            connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
        fi
        if [ -n "${option_port}" ]; then
            connect_options+=(--protocol=tcp)
            connect_options+=(--port="${option_port}")
        fi
        if [ -n "${option_socket}" ]; then
            connect_options+=(--protocol=socket)
            connect_options+=(--socket="${option_socket}")
        fi
        if [ -n "${option_user}" ]; then
            connect_options+=(--user="${option_user}")
        fi
        if [ -n "${option_password}" ]; then
            connect_options+=(--password="${option_password}")
        fi

        declare -a options
        options=()
        options+=(--sleep=0)

        pt-mysql-summary "${options[@]}" -- "${connect_options[@]}" 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pt-mysql-summary to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'pt-mysql-summary' not found, unable to dump summary"
    fi
}

#######################################################################
# Dump grants of an instance
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_grants() {
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                exit 1
                ;;
            --dump-label)
                # dump-label options, with value separated by space
                if [ -n "$2" ]; then
                    option_dump_label="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --dump-label=?*)
                # dump-label options, with value separated by =
                option_dump_label="${1#*=}"
                ;;
            --dump-label=)
                # dump-label options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    # DO NOT REMOVE EXISTING DIRECTORIES
    # rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    ## Dump all grants (requires 'percona-toolkit' package)
    if command -v pt-show-grants > /dev/null; then
        local error_file="${errors_dir}/all_grants.err"
        local dump_file="${dump_dir}/all_grants.sql"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        declare -a options
        options=()
        if [ -n "${option_defaults_file}" ]; then
            options+=(--defaults-file="${option_defaults_file}")
        fi
        if [ -n "${option_port}" ]; then
            options+=(--port="${option_port}")
        fi
        if [ -n "${option_socket}" ]; then
            options+=(--socket="${option_socket}")
        fi
        if [ -n "${option_user}" ]; then
            options+=(--user="${option_user}")
        fi
        if [ -n "${option_password}" ]; then
            options+=(--password="${option_password}")
        fi
        options+=(--flush)
        options+=(--no-header)

        pt-show-grants "${options[@]}" 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: pt-show-grants to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'pt-show-grants' not found, unable to dump grants"
    fi
}

#######################################################################
# Dump a single compressed file of all databases of an instance
#
# Arguments:
# --masterdata (default: <absent>)
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_global() {
    local option_masterdata=""
    local option_port=""
    local option_socket=""
    local option_defaults_file=""
    local option_defaults_extra_file=""
    local option_defaults_group_suffix=""
    local option_user=""
    local option_password=""
    local option_dump_label=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --masterdata)
                option_masterdata="--masterdata"
                ;;
            --defaults-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-file=?*)
                # defaults-file options, with value separated by =
                option_defaults_file="${1#*=}"
                ;;
            --defaults-file=)
                # defaults-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-extra-file)
                # defaults-file options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_extra_file="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-file' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-extra-file=?*)
                # defaults-extra-file options, with value separated by =
                option_defaults_extra_file="${1#*=}"
                ;;
            --defaults-extra-file=)
                # defaults-extra-file options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-extra-file' requires a non-empty option argument."
                exit 1
                ;;
            --defaults-group-suffix)
                # defaults-group-suffix options, with value separated by space
                if [ -n "$2" ]; then
                    option_defaults_group_suffix="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --defaults-group-suffix=?*)
                # defaults-group-suffix options, with value separated by =
                option_defaults_group_suffix="${1#*=}"
                ;;
            --defaults-group-suffix=)
                # defaults-group-suffix options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--defaults-group-suffix' requires a non-empty option argument."
                exit 1
                ;;
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                exit 1
                ;;
            --user)
                # user options, with value separated by space
                if [ -n "$2" ]; then
                    option_user="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --user=?*)
                # user options, with value separated by =
                option_user="${1#*=}"
                ;;
            --user=)
                # user options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--user' requires a non-empty option argument."
                exit 1
                ;;
            --password)
                # password options, with value separated by space
                if [ -n "$2" ]; then
                    option_password="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --password=?*)
                # password options, with value separated by =
                option_password="${1#*=}"
                ;;
            --password=)
                # password options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--password' requires a non-empty option argument."
                exit 1
                ;;
            --dump-label)
                # dump-label options, with value separated by space
                if [ -n "$2" ]; then
                    option_dump_label="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --dump-label=?*)
                # dump-label options, with value separated by =
                option_dump_label="${1#*=}"
                ;;
            --dump-label=)
                # dump-label options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--dump-label' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    if [ -z "${option_dump_label}" ]; then
        if [ -n "${option_defaults_group_suffix}" ]; then
            option_dump_label="${option_defaults_group_suffix}"
        elif [ -n "${option_port}" ]; then
            option_dump_label="${option_port}"
        else
            option_dump_label="default"
        fi
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/mysqldump.err"
    local dump_file="${dump_dir}/mysqldump.sql.gz"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    ## Connection options
    declare -a connect_options
    connect_options=()
    if [ -n "${option_defaults_file}" ]; then
        connect_options+=(--defaults-file="${option_defaults_file}")
    fi
    if [ -n "${option_defaults_extra_file}" ]; then
        connect_options+=(--defaults-extra-file="${option_defaults_extra_file}")
    fi
    if [ -n "${option_defaults_group_suffix}" ]; then
        connect_options+=(--defaults-group-suffix="${option_defaults_group_suffix}")
    fi
    if [ -n "${option_port}" ]; then
        connect_options+=(--protocol=tcp)
        connect_options+=(--port="${option_port}")
    fi
    if [ -n "${option_socket}" ]; then
        connect_options+=(--protocol=socket)
        connect_options+=(--socket="${option_socket}")
    fi
    if [ -n "${option_user}" ]; then
        connect_options+=(--user="${option_user}")
    fi
    if [ -n "${option_password}" ]; then
        connect_options+=(--password="${option_password}")
    fi

    ## Global all databases in one file
    declare -a dump_options
    dump_options=()
    dump_options+=(--opt)
    dump_options+=(--force)
    dump_options+=(--events)
    dump_options+=(--hex-blob)
    dump_options+=(--all-databases)
    if [ -n "${option_masterdata}" ]; then
        dump_options+=("${option_masterdata}")
    fi

    mysqldump "${connect_options[@]}" "${dump_options[@]}" 2> "${error_file}" | gzip --best > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"

    ## Schema only (no data) for each databases
    local error_file="${errors_dir}/mysqldump.schema.err"
    local dump_file="${dump_dir}/mysqldump.schema.sql"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    declare -a dump_options
    dump_options=()
    dump_options+=(--force)
    dump_options+=(--no-data)
    dump_options+=(--all-databases)

    mysqldump "${connect_options[@]}" "${dump_options[@]}" 2> "${error_file}" > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
}

#######################################################################
# Dump a compressed file per database of an instance
#
# Arguments:
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_per_base() {
    local option_port=""
    local option_socket=""
    local option_dump_label=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    option_dump_label="${option_dump_label:-default}"

    declare -a connect_options
    connect_options=()
    if [ -n "${option_port}" ]; then
        connect_options+=(--port="${option_port}")
    fi
    if [ -n "${option_socket}" ]; then
        connect_options+=(--protocol=socket)
        connect_options+=(--socket="${option_socket}")
    fi

    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}/databases"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    declare -a options
    options=()
    options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
    options+=(--force)
    options+=(--events)
    options+=(--hex-blob)

    databases=$(mysql_list_databases "${connect_options[@]}")

    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.err"
        local dump_file="${dump_dir}/${database}.sql.gz"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        mysqldump "${connect_options[@]}" "${options[@]}" "${database}" 2> "${error_file}" | gzip --best > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    done

    ## Schema only (no data) for each databases
    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.schema.err"
        local dump_file="${dump_dir}/${database}.schema.sql"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        declare -a options
        options=()
        options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
        options+=(--force)
        options+=(--no-data)
        options+=(--databases "${database}")

        mysqldump "${connect_options[@]}" "${options[@]}" 2> "${error_file}" > "${dump_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    done

    ## Grants and summary
    if [ -n "${option_port}" ]; then
        dump_mysql_grants --port="${option_port}"
        dump_mysql_summary --port="${option_port}"
    elif [ -n "${option_socket}" ]; then
        dump_mysql_grants --socket="${option_socket}"
        dump_mysql_summary --socket="${option_socket}"
    else
        dump_mysql_grants
        dump_mysql_summary
    fi
}

#######################################################################
# Dump "tabs style" separate schema/data for each database of an instance
#
# Arguments:
# --masterdata (default: <absent>)
# --port=[Integer] (default: <blank>)
# --socket=[String] (default: <blank>)
# --user=[String] (default: <blank>)
# --password=[String] (default: <blank>)
# --defaults-file=[String] (default: <blank>)
# --defaults-extra-file=[String] (default: <blank>)
# --defaults-group-suffix=[String] (default: <blank>)
# --dump-label=[String] (default: "default")
#   used as suffix of the dump dir to differenciate multiple instances
#######################################################################
dump_mysql_tabs() {
    local option_port=""
    local option_socket=""
    local option_dump_label=""
    # Parse options, based on https://gist.github.com/deshion/10d3cb5f88a21671e17a
    while :; do
        case ${1:-''} in
            --port)
                # port options, with value separated by space
                if [ -n "$2" ]; then
                    option_port="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --port=?*)
                # port options, with value separated by =
                option_port="${1#*=}"
                ;;
            --port=)
                # port options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--port' requires a non-empty option argument."
                exit 1
                ;;
            --socket)
                # socket options, with value separated by space
                if [ -n "$2" ]; then
                    option_socket="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --socket=?*)
                # socket options, with value separated by =
                option_socket="${1#*=}"
                ;;
            --socket=)
                # socket options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--socket' requires a non-empty option argument."
                exit 1
                ;;
            --)
                # End of all options.
                shift
                break
                ;;
            -?*|[[:alnum:]]*)
                # ignore unknown options
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: unknown option '${1}' (ignored)"
                ;;
            *)
                # Default case: If no more options then break out of the loop.
                break
                ;;
        esac

        shift
    done

    option_dump_label="${option_dump_label:-default}"

    databases=$(mysql_list_databases "${option_port}")

    for database in ${databases}; do
        local dump_dir="${LOCAL_BACKUP_DIR}/mysql-${option_dump_label}/tabs/${database}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        mkdir -p "${dump_dir}" "${errors_dir}"
        # No need to change recursively, the top directory is enough
        chmod 700 "${dump_dir}" "${errors_dir}"
        chown -RL mysql "${dump_dir}"

        local error_file="${errors_dir}.err"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

        declare -a options
        options=()
        options+=(--defaults-extra-file=/etc/mysql/debian.cnf)
        if [ -n "${option_port}" ]; then
            options+=(--port="${option_port}")
        fi
        if [ -n "${option_socket}" ]; then
            options+=(--protocol=socket)
            options+=(--socket="${option_socket}")
        fi
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
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mysqldump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
    done
}
