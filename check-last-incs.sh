#!/bin/sh

inc_exists() {
    ls -d /backup/incs/$1 > /dev/null 2>&1
}
# default return value is 0 (succes)
rc=0
# loop for each found jail
for file in /backup/jails/*; do
    jail_name=$(basename ${file})
    # inc date in seconds from epoch
    inc_date=$(date --date "yesterday" +"%Y-%m-%d")
    # Error if inc is not found
    if ! inc_exists ${jail_name}/${inc_date}*; then
        echo "ERROR: inc is missing \`${jail_name}/${inc_date}'" >&2
        rc=1
    fi
done

exit $rc
