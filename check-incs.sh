#!/bin/sh

EVOBACKUP_CONFIGS="/etc/evobackup/*"

relative_date() {
    format=$(echo $1 | cut -d'.' -f1)
    time_jump=$(echo $1 | cut -d'.' -f2)
 
    reference_date=$(date "${format}")
    past_date=$(date --date "${reference_date} ${time_jump}" +"%Y-%m-%d")
    
    echo ${past_date}
}
inc_exists() {
    ls -d /backup/incs/$1 > /dev/null 2>&1 
}
jail_exists() {
    ls -d /backup/jails/$1 > /dev/null 2>&1 
}
# default return value is 0 (succes)
rc=0
# loop for each configured jail
for file in ${EVOBACKUP_CONFIGS}; do
    jail_name=$(basename $file) 
    # check if jail is present
    if jail_exists ${jail_name}; then
        # get jail last configuration date
        jail_config_age=$(date --date "$(stat -c %y ${file})" +%s)
        # loop for each line in jail configuration
        for line in $(cat $file); do
            # inc date in ISO format
            inc_date=$(relative_date $line)
            # inc date in seconds from epoch
            inc_age=$(date --date "${inc_date}" +%s)
            # check if the configuration changed after the inc date 
            if [ $jail_config_age -lt $inc_age ]; then
                # Error if inc is not found
                if ! inc_exists ${jail_name}/${inc_date}*; then
                    echo "ERROR: inc is missing \`${jail_name}/${inc_date}'" >&2
                    rc=1
                fi
            else
                echo "INFO: no inc expected for ${inc_date} \`${jail_name}'"
            fi
        done
    else
        echo "ERROR: jail is missing \`${jail_name}'" >&2
        rc=1
    fi
done

exit $rc
