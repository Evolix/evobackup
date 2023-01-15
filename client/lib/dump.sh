#!/bin/bash
# shellcheck disable=SC2034,SC2317

mysql_list_databases() {
    port=${1:-"3306"}

    mysql --defaults-extra-file=/etc/mysql/debian.cnf --port="${port}" --execute="show databases" --silent --skip-column-names \
        | grep --extended-regexp --invert-match "^(Database|information_schema|performance_schema|sys)"
}

### BEGIN Dump functions ####

dump_from_lib() {
    echo "Dump from lib"
}

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
dump_mysql_global() {
    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-global"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    local error_file="${errors_dir}/mysql.bak.err"
    local dump_file="${dump_dir}/mysql.bak.gz"
    log "LOCAL_TASKS - start ${dump_file}"

    mysqldump --defaults-extra-file=/etc/mysql/debian.cnf -P 3306 --opt --all-databases --force --events --hex-blob 2> "${error_file}" | gzip --best > "${dump_file}"

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
dump_mysql_per_base() {
    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-per-base"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    databases=$(mysql_list_databases 3306)
    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.err"
        local dump_file="${dump_dir}/${database}.sql.gz"
        log "LOCAL_TASKS - start ${dump_file}"

        mysqldump --defaults-extra-file=/etc/mysql/debian.cnf --force -P 3306 --events --hex-blob "${database}" 2> "${error_file}" | gzip --best > "${dump_file}"

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
dump_mysql_meta() {
    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-meta"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    ## Dump all grants (requires 'percona-toolkit' package)
    local error_file="${errors_dir}/all_grants.err"
    local dump_file="${dump_dir}/all_grants.sql"
    log "LOCAL_TASKS - start ${dump_file}"

    pt-show-grants --flush --no-header 2> "${error_file}" > "${dump_file}"

    local last_rc=$?
    # shellcheck disable=SC2086
    if [ ${last_rc} -ne 0 ]; then
        log_error "LOCAL_TASKS - pt-show-grants to ${dump_file} returned an error ${last_rc}" "${error_file}"
        GLOBAL_RC=${E_DUMPFAILED}
    else
        rm -f "${error_file}"
    fi
    log "LOCAL_TASKS - stop  ${dump_file}"

    ## Dump all variables
    local error_file="${errors_dir}/variables.err"
    local dump_file="${dump_dir}/variables.txt"
    log "LOCAL_TASKS - start ${dump_file}"

    mysql -A -e "SHOW GLOBAL VARIABLES;" 2> "${error_file}" > "${dump_file}"

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
    databases=$(mysql_list_databases 3306)
    for database in ${databases}; do
        local error_file="${errors_dir}/${database}.schema.err"
        local dump_file="${dump_dir}/${database}.schema.sql"
        log "LOCAL_TASKS - start ${dump_file}"

        mysqldump --defaults-extra-file=/etc/mysql/debian.cnf --force -P 3306 --no-data --databases "${database}" 2> "${error_file}" > "${dump_file}"

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
dump_mysql_tabs() {
    databases=$(mysql_list_databases 3306)
    for database in ${databases}; do
        local dump_dir="${LOCAL_BACKUP_DIR}/mysql-tabs/${database}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        # shellcheck disable=SC2174
        mkdir -p -m 700 "${dump_dir}" "${errors_dir}"
        chown -RL mysql "${dump_dir}"

        local error_file="${errors_dir}.err"
        log "LOCAL_TASKS - start ${dump_dir}"

        mysqldump --defaults-extra-file=/etc/mysql/debian.cnf --force -P 3306 -Q --opt --events --hex-blob --skip-comments --fields-enclosed-by='\"' --fields-terminated-by=',' -T "${dump_dir}" "${database}" 2> "${error_file}"
 
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
dump_mysql_hotcopy() {
    # customize the list of databases to hot-copy
    databases=""
    for database in ${databases}; do
        local dump_dir="${LOCAL_BACKUP_DIR}/mysql-hotcopy/${database}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        # shellcheck disable=SC2174
        mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

        local error_file="${errors_dir}.err"
        log "LOCAL_TASKS - start ${dump_dir}"

        mysqlhotcopy "${database}" "${dump_dir}/" 2> "${error_file}"

        local last_rc=$?
        # shellcheck disable=SC2086
        if [ ${last_rc} -ne 0 ]; then
            log_error "LOCAL_TASKS - mysqlhotcopy to ${dump_dir} returned an error ${last_rc}" "${error_file}"
            GLOBAL_RC=${E_DUMPFAILED}
        else
            rm -f "${error_file}"
        fi
        log "LOCAL_TASKS - stop  ${dump_dir}"
    done
}
dump_mysql_instances() {
    local dump_dir="${LOCAL_BACKUP_DIR}/mysql-instances"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    mysql_user="mysqladmin"
    mysql_passwd=$(grep -m1 'password = .*' /root/.my.cnf | cut -d " " -f 3)

    # customize list of instances
    instances=""
    for instance in ${instances}; do
        local error_file="${errors_dir}/${instance}.err"
        local dump_file="${dump_dir}/${instance}.bak.gz"
        log "LOCAL_TASKS - start ${dump_file}"

        mysqldump --port="${instance}" --opt --all-databases --hex-blob --user="${mysql_user}" --password="${mysql_passwd}" 2> "${error_file}" | gzip --best > "${dump_file}"

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
dump_postgresql_global() {
    local dump_dir="${LOCAL_BACKUP_DIR}/postgresql-global"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    ## example with pg_dumpall and with compression
    local dump_file="${dump_dir}/pg.dump.bak.gz"
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
    # local dump_file="${dump_dir}/pg.dump.bak"
    # log "LOCAL_TASKS - start ${dump_file}"
    # 
    # (su - postgres -c "pg_dumpall > ~/pg.dump.bak") 2> "${error_file}"
    # mv ~postgres/pg.dump.bak "${dump_file}"
    # 
    # log "LOCAL_TASKS - stop  ${dump_file}"
}
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

            (sudo -u postgres /usr/bin/pg_dump --create -s -U postgres -d "${database}") 2> "${error_file}" | gzip --best > "${dump_file}"

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
dump_redis() {
    instances=$(find /var/lib/ -mindepth 1 -maxdepth 1 -type d -name 'redis*')
    for instance in ${instances}; do
        name=$(basename "${instance}")
        local dump_dir="${LOCAL_BACKUP_DIR}/${name}"
        local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
        rm -rf "${dump_dir}" "${errors_dir}"
        # shellcheck disable=SC2174
        mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

        if [ -f "${instance}/dump.rdb" ]; then
            local error_file="${errors_dir}/${instance}.err"
            log "LOCAL_TASKS - start ${dump_dir}"

            cp -a "${instance}/dump.rdb" "${dump_dir}/" 2> "${error_file}"

            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - cp ${instance}/dump.rdb to ${dump_dir} returned an error ${last_rc}" "${error_file}"
                GLOBAL_RC=${E_DUMPFAILED}
            else
                rm -f "${error_file}"
            fi
            log "LOCAL_TASKS - stop  ${dump_dir}"
        fi
    done
}
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

    mongo_user=""
    mongo_password=""

    mongodump -u "${mongo_user}" -p"${mongo_password}" -o "${dump_dir}/" 2> "${error_file}" > /dev/null

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
dump_traceroute() {
    local dump_dir="${LOCAL_BACKUP_DIR}/traceroute"
    local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
    rm -rf "${dump_dir}" "${errors_dir}"
    # shellcheck disable=SC2174
    mkdir -p -m 700 "${dump_dir}" "${errors_dir}"

    network_targets="8.8.8.8 www.evolix.fr travaux.evolix.net"

    mtr_bin=$(command -v mtr)
    if [ -n "${network_targets}" ] && [ -n "${mtr_bin}" ]; then
        for addr in ${network_targets}; do
            local dump_file="${dump_dir}/mtr-${addr}"
            log "LOCAL_TASKS - start ${dump_file}"

            ${mtr_bin} -r "${addr}" > "${dump_file}"

            log "LOCAL_TASKS - stop  ${dump_file}"
        done
    fi

    traceroute_bin=$(command -v traceroute)
    if [ -n "${network_targets}" ] && [ -n "${traceroute_bin}" ]; then
        for addr in ${network_targets}; do
            local dump_file="${dump_dir}/traceroute-${addr}"
            log "LOCAL_TASKS - start ${dump_file}"

            ${traceroute_bin} -n "${addr}" > "${dump_file}" 2>&1

            log "LOCAL_TASKS - stop  ${dump_file}"
        done
    fi
}
dump_server_state() {
    local dump_dir="${LOCAL_BACKUP_DIR}/server-state"
    rm -rf "${dump_dir}"
    # Do not create the directory
    # shellcheck disable=SC2174
    # mkdir -p -m 700 "${dump_dir}"

    log "LOCAL_TASKS - start ${dump_dir}"

    dump_server_state_bin=$(command -v dump-server-state)
    if [ -z "${dump_server_state_bin}" ]; then
        log_error "LOCAL_TASKS - dump-server-state is missing"
        rc=1
    else
        if [ "${SYSTEM}" = "linux" ]; then
            ${dump_server_state_bin} --all --dump-dir "${dump_dir}"
            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - dump-server-state returned an error ${last_rc}, check ${dump_dir}"
                GLOBAL_RC=${E_DUMPFAILED}
            fi
        else
            ${dump_server_state_bin} --all --dump-dir "${dump_dir}"
            local last_rc=$?
            # shellcheck disable=SC2086
            if [ ${last_rc} -ne 0 ]; then
                log_error "LOCAL_TASKS - dump-server-state returned an error ${last_rc}, check ${dump_dir}"
                GLOBAL_RC=${E_DUMPFAILED}
            fi
        fi
    fi
    log "LOCAL_TASKS - stop  ${dump_dir}"
}
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
dump_elasticsearch_snapshot() {
    log "LOCAL_TASKS - start dump_elasticsearch_snapshot"

    ## Take a snapshot as a backup.
    ## Warning: You need to have a path.repo configured.
    ## See: https://wiki.evolix.org/HowtoElasticsearch#snapshots-et-sauvegardes

    curl -s -XDELETE "localhost:9200/_snapshot/snaprepo/snapshot.daily" >> "${LOGFILE}"
    curl -s -XPUT "localhost:9200/_snapshot/snaprepo/snapshot.daily?wait_for_completion=true" >> "${LOGFILE}"

    # Clustered version here
    # It basically the same thing except that you need to check that NFS is mounted
    # if ss | grep ':nfs' | grep -q 'ip\.add\.res\.s1' && ss | grep ':nfs' | grep -q 'ip\.add\.res\.s2'
    # then
    #     curl -s -XDELETE "localhost:9200/_snapshot/snaprepo/snapshot.daily" >> "${LOGFILE}"
    #     curl -s -XPUT "localhost:9200/_snapshot/snaprepo/snapshot.daily?wait_for_completion=true" >> "${LOGFILE}"
    # else
    #     echo 'Cannot make a snapshot of elasticsearch, at least one node is not mounting the repository.'
    # fi

    ## If you need to keep older snapshot, for example the last 10 daily snapshots, replace the XDELETE and XPUT lines by :
    # for snapshot in $(curl -s -XGET "localhost:9200/_snapshot/snaprepo/_all?pretty=true" | grep -Eo 'snapshot_[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n -10); do
    #     curl -s -XDELETE "localhost:9200/_snapshot/snaprepo/${snapshot}" | grep -v -Fx '{"acknowledged":true}'
    # done
    # date=$(/bin/date +%F)
    # curl -s -XPUT "localhost:9200/_snapshot/snaprepo/snapshot_${date}?wait_for_completion=true" >> "${LOGFILE}"

    log "LOCAL_TASKS - stop  dump_elasticsearch_snapshot"
}