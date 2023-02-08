#!/bin/bash
#
# Script Evobackup client
# See https://gitea.evolix.org/evolix/evobackup
#
# Authors: Evolix <info@evolix.fr>,
#          Gregory Colpart <reg@evolix.fr>,
#          Romain Dessort <rdessort@evolix.fr>,
#          Benoit Série <bserie@evolix.fr>,
#          Tristan Pilat <tpilat@evolix.fr>,
#          Victor Laborie <vlaborie@evolix.fr>,
#          Jérémy Lecour <jlecour@evolix.fr>
#          and others.
#
# Licence: AGPLv3

#######################################################################
#
# You must configure the MAIL variable to receive notifications.
#
# There is some optional configuration that you can do
# at the end of this script.
#
# The library (usually installed at /usr/local/lib/evobackup/main.sh)
# also has many variables that you can override for fine-tuning.
#
#######################################################################

# Email adress for notifications
MAIL=jdoe@example.com

#######################################################################
#
# The "sync_tasks" function will be called by the main function. 
#
# You can customize the variables:
# * "sync_name"      (String)
# * "SERVERS"        (Array of HOST:PORT)
# * "RSYNC_INCLUDES" (Array of paths to include)
# * "RSYNC_EXCLUDES" (Array of paths to exclude)
#
# The "sync" function can be called multiple times
# with a different set of variables.
# That way you can to sync to various destinations.
#
#######################################################################

sync_tasks() {

    ########## System-only backup (to Evolix servers) #################

    # Name your sync task, for logs
    sync_name="evolix-system"

    # List of host/port for your sync task
    # shellcheck disable=SC2034
    SERVERS=(
        node0.backup.evolix.net:2234
        node1.backup.evolix.net:2234
    )

    # What to include in your sync task
    # Add or remove paths if you need
    # shellcheck disable=SC2034
    RSYNC_INCLUDES=(
        "${rsync_default_includes[@]}"
        /etc
        /root
        /var
    )

    # What to exclude from your sync task
    # Add or remove paths if you need
    # shellcheck disable=SC2034
    RSYNC_EXCLUDES=(
        "${rsync_default_excludes[@]}"
    )

    # Call the sync task
    sync "${sync_name}" "SERVERS[@]" "RSYNC_INCLUDES[@]" "RSYNC_EXCLUDES[@]"


    ########## Full backup (to client servers) ########################

    # Name your sync task, for logs
    sync_name="client-full"

    # List of host/port for your sync task
    # shellcheck disable=SC2034
    SERVERS=(
        client-backup00.evolix.net:2221
        client-backup01.evolix.net:2221
    )

    # What to include in your sync task
    # Add or remove paths if you need
    # shellcheck disable=SC2034
    RSYNC_INCLUDES=(
        "${rsync_default_includes[@]}"
        /etc
        /root
        /var
        /home
        /srv
    )

    # What to exclude from your sync task
    # Add or remove paths if you need
    # shellcheck disable=SC2034
    RSYNC_EXCLUDES=(
        "${rsync_default_excludes[@]}"
    )

    # Call the sync task
    sync "${sync_name}" "SERVERS[@]" "RSYNC_INCLUDES[@]" "RSYNC_EXCLUDES[@]"

}

#######################################################################
#
# The "local_tasks" function will be called by the main function. 
#
# You can call any available "dump_xxx" function
# (usually installed at /usr/local/lib/evobackup/dump.sh)
#
# You can also write some custom functions and call them.
# A "dump_custom" example is available further down.
#
#######################################################################

local_tasks() {

    ########## OpenLDAP ###############

    ### dump_ldap

    ########## MySQL ##################

    # Dump all grants (permissions), config variables and schema of databases
    ### dump_mysql_meta [--port=3306]

    # Dump all databases in a single compressed file
    ### dump_mysql_global [--port=3306] [--masterdata]
    
    # Dump each database separately, in a compressed file
    ### dump_mysql_per_base [--port=3306]
 
    # Dump multiples instances, each in a single compressed file
    ### dump_mysql_instance [--port=3306]

    # Dump each table in schema/data files, for all databases
    ### dump_mysql_tabs [--port=3306] [--user=foo] [--password=123456789]

    ########## PostgreSQL #############

    # Dump all databases in a single file (compressed or not)
    ### dump_postgresql_global

    # Dump a specific databse with only some tables, or all but some tables (must be configured)
    ### dump_postgresql_filtered

    # Dump each database separately, in a compressed file
    ### dump_postgresql_per_base

    ########## MongoDB ################
    
    ### dump_mongodb [--user=foo] [--password=123456789]

    ########## Redis ##################

    # Copy data file for all instances
    ### dump_redis [--instances=<all|instance1|instance2>]

    ########## Elasticsearch ##########

    # Snapshot data for a single-node cluster
    ### dump_elasticsearch_snapshot_singlenode [--protocol=http] [--host=localhost] [--port=9200] [--user=foo] [--password=123456789] [--repository=snaprepo] [--snapshot=snapshot.daily]

    # Snapshot data for a multi-node cluster
    ### dump_elasticsearch_snapshot_multinode [--protocol=http] [--host=localhost] [--port=9200] [--user=foo] [--password=123456789] [--repository=snaprepo] [--snapshot=snapshot.daily] [--nfs-server=192.168.2.1]

    ########## RabbitMQ ###############

    ### dump_rabbitmq

    ########## MegaCli ################

    # Copy RAID config
    ### dump_megacli_config

    ########## Network ################

    # Dump network routes with mtr and traceroute (warning: could be long with aggressive firewalls)
    dump_traceroute --targets=8.8.8.8,www.evolix.fr,travaux.evolix.net

    ########## Server state ###########

    # Run dump-server-state to extract system information
    dump_server_state

    # Dump file access control lists
    ### dump_facl

    # No-op, in case nothing is enabled
    :
}

# This is an example for a custom dump function
# Uncomment, customize and call it from the "local_tasks" function
### dump_custom() {
###     # Set dump and errors directories and files
###     local dump_dir="${LOCAL_BACKUP_DIR}/custom"
###     local dump_file="${dump_dir}/dump.gz"
###     local errors_dir=$(errors_dir_from_dump_dir "${dump_dir}") 
###     local error_file="${errors_dir}/dump.err"
### 
###     # Reset dump and errors directories
###     rm -rf "${dump_dir}" "${errors_dir}"
###     # shellcheck disable=SC2174
###     mkdir -p -m 700 "${dump_dir}" "${errors_dir}"
###
###     # Log the start of the command
###     log "LOCAL_TASKS - start ${dump_file}"
###
###     # Execute your dump command
###     # Send errors to the error file and the data to the dump file
###     my-dump-command 2> "${error_file}" > "${dump_file}"
###
###     # Check result and deal with potential errors
###     local last_rc=$?
###     # shellcheck disable=SC2086
###     if [ ${last_rc} -ne 0 ]; then
###         log_error "LOCAL_TASKS - my-dump-command to ${dump_file} returned an error ${last_rc}" "${error_file}"
###         GLOBAL_RC=${E_DUMPFAILED}
###     else
###         rm -f "${error_file}"
###     fi
###
###     # Log the end of the command
###     log "LOCAL_TASKS - stop  ${dump_file}"
### }

########## Optional configuration #####################################

setup_custom() {
    # If you set a value (like "linux", "openbsd"…) it will be used,
    # Default: uname(1) in lowercase.
    ### SYSTEM="linux"

    # If you set a value it will be used,
    # Default: hostname(1).
    ### HOSTNAME="example-host"

    # Email subect for notifications
    ### MAIL_SUBJECT="[info] EvoBackup - Client ${HOSTNAME}"

    # No-op in case nothing is executed
    :
}

########## Libraries ##################################################

# Change this to wherever you install the libraries
LIBDIR="./lib"

source "${LIBDIR}/main.sh"

########## Let's go! ##################################################

main