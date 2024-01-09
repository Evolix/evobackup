#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317,SC2155

#######################################################################
# Dump LDAP files (config, data, all)
#
# Arguments: <none>
#######################################################################
dump_ldap() {
    ## OpenLDAP : example with slapcat
    local dump_dir="${LOCAL_BACKUP_DIR}/ldap"
    rm -rf "${dump_dir}"
    mkdir -p "${dump_dir}"
    chmod 700 "${dump_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${FUNCNAME[0]} to ${dump_dir}"

    slapcat -n 0 -l "${dump_dir}/config.bak"
    slapcat -n 1 -l "${dump_dir}/data.bak"
    slapcat      -l "${dump_dir}/all.bak"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${FUNCNAME[0]}"
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
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--instances' requires a non-empty option argument."
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
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--instances' requires a non-empty option argument."
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
    
    for instance in "${option_instances[@]}"; do
        name=$(basename "${instance}")
        local dump_dir="${LOCAL_BACKUP_DIR}/${name}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        mkdir -p "${dump_dir}" "${errors_dir}"
        # No need to change recursively, the top directory is enough
        chmod 700 "${dump_dir}" "${errors_dir}"

        if [ -f "${instance}/dump.rdb" ]; then
            local error_file="${errors_dir}/${name}.err"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

            cp -a "${instance}/dump.rdb" "${dump_dir}/dump.rdb" 2> "${error_file}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: cp ${instance}/dump.rdb to ${dump_dir} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi

            gzip "${dump_dir}/dump.rdb"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: gzip ${dump_dir}/dump.rdb returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi

            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
        else
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '${instance}/dump.rdb' not found."
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
#
# don't forget to create use with read-only access
# > use admin
# > db.createUser( { user: "mongobackup", pwd: "PASS", roles: [ "backup", ] } )
#######################################################################
dump_mongodb() {
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

    local dump_dir="${LOCAL_BACKUP_DIR}/mongodump"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

    declare -a options
    options=()
    options+=(--username="${option_user}")
    options+=(--password="${option_password}")
    options+=(--out="${dump_dir}/")

    mongodump "${options[@]}" 2> "${error_file}" > /dev/null

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: mongodump to ${dump_dir} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${FUNCNAME[0]}: ${dump_dir}"
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
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    if command -v megacli > /dev/null; then
        local error_file="${errors_dir}/megacli.cfg"
        local dump_file="${dump_dir}/megacli.err"
        log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

        megacli -CfgSave -f "${dump_file}" -a0 2> "${error_file}" > /dev/null

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: megacli to ${dump_file} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
    else
        log "LOCAL_TASKS - ${FUNCNAME[0]}: 'megacli' not found, unable to dump RAID configuration"
    fi
}





#######################################################################
# Save some traceroute/mtr results
#
# Arguments:
# --targets=[IP,HOST] (default: <none>)
#######################################################################
dump_traceroute() {
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
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--targets' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --targets=?*)
                # targets options, with key and value separated by =
                IFS="," read -a option_targets <<< "${1#*=}"
                ;;
            --targets=)
                # targets options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--targets' requires a non-empty option argument."
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

    local dump_dir="${LOCAL_BACKUP_DIR}/traceroute"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"


    mtr_bin=$(command -v mtr)
    if [ -n "${mtr_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/mtr-${target}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            ${mtr_bin} -r "${target}" > "${dump_file}"

            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
        done
    fi

    traceroute_bin=$(command -v traceroute)
    if [ -n "${traceroute_bin}" ]; then
        for target in "${option_targets[@]}"; do
            local dump_file="${dump_dir}/traceroute-${target}"
            log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

            ${traceroute_bin} -n "${target}" > "${dump_file}" 2>&1

            log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_file}"
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
    # mkdir -p -m 700 "${dump_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

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
        log_error "LOCAL_TASKS - ${FUNCNAME[0]}: dump-server-state is missing"
        rc=1
    else
        ${dump_server_state_bin} "${options[@]}"
        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - ${FUNCNAME[0]}: dump-server-state returned an error ${last_rc}, check ${dump_dir}"
            GLOBAL_RC=${E_DUMPFAILED}
        fi
    fi
    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
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
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}.err"
    local dump_file="${dump_dir}/config"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_file}"

    rabbitmqadmin export "${dump_file}" 2> "${error_file}" >> "${LOGFILE}"

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

#######################################################################
# Save Files ACL on various partitions.
# 
# Arguments: <none>
#######################################################################
dump_facl() {
    local dump_dir="${LOCAL_BACKUP_DIR}/facl"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    mkdir -p "${dump_dir}" "${errors_dir}"
    # No need to change recursively, the top directory is enough
    chmod 700 "${dump_dir}" "${errors_dir}"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${dump_dir}"

    getfacl -R /etc  > "${dump_dir}/etc.txt"
    getfacl -R /home > "${dump_dir}/home.txt"
    getfacl -R /usr  > "${dump_dir}/usr.txt"
    getfacl -R /var  > "${dump_dir}/var.txt"

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${dump_dir}"
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
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --protocol=?*)
                # protocol options, with value separated by =
                option_protocol="${1#*=}"
                ;;
            --protocol=)
                # protocol options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                exit 1
                ;;
            --host)
                # host options, with value separated by space
                if [ -n "$2" ]; then
                    option_host="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --host=?*)
                # host options, with value separated by =
                option_host="${1#*=}"
                ;;
            --host=)
                # host options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
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
            --repository)
                # repository options, with value separated by space
                if [ -n "$2" ]; then
                    option_repository="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --repository=?*)
                # repository options, with value separated by =
                option_repository="${1#*=}"
                ;;
            --repository=)
                # repository options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                exit 1
                ;;
            --snapshot)
                # snapshot options, with value separated by space
                if [ -n "$2" ]; then
                    option_snapshot="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --snapshot=?*)
                # snapshot options, with value separated by =
                option_snapshot="${1#*=}"
                ;;
            --snapshot=)
                # snapshot options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
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

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${option_snapshot}"

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

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${option_snapshot}"
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
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --protocol=?*)
                # protocol options, with value separated by =
                option_protocol="${1#*=}"
                ;;
            --protocol=)
                # protocol options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--protocol' requires a non-empty option argument."
                exit 1
                ;;
            --host)
                # host options, with value separated by space
                if [ -n "$2" ]; then
                    option_host="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --host=?*)
                # host options, with value separated by =
                option_host="${1#*=}"
                ;;
            --host=)
                # host options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--host' requires a non-empty option argument."
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
            --repository)
                # repository options, with value separated by space
                if [ -n "$2" ]; then
                    option_repository="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --repository=?*)
                # repository options, with value separated by =
                option_repository="${1#*=}"
                ;;
            --repository=)
                # repository options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--repository' requires a non-empty option argument."
                exit 1
                ;;
            --snapshot)
                # snapshot options, with value separated by space
                if [ -n "$2" ]; then
                    option_snapshot="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --snapshot=?*)
                # snapshot options, with value separated by =
                option_snapshot="${1#*=}"
                ;;
            --snapshot=)
                # snapshot options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--snapshot' requires a non-empty option argument."
                exit 1
                ;;
            --nfs-server)
                # nfs-server options, with value separated by space
                if [ -n "$2" ]; then
                    option_nfs_server="${2}"
                    shift
                else
                    log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--nfs-server' requires a non-empty option argument."
                    exit 1
                fi
                ;;
            --nfs-server=?*)
                # nfs-server options, with value separated by =
                option_nfs_server="${1#*=}"
                ;;
            --nfs-server=)
                # nfs-server options, without value
                log_error "LOCAL_TASKS - ${FUNCNAME[0]}: '--nfs-server' requires a non-empty option argument."
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

    log "LOCAL_TASKS - ${FUNCNAME[0]}: start ${option_snapshot}"

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

    log "LOCAL_TASKS - ${FUNCNAME[0]}: stop  ${option_snapshot}"
}
