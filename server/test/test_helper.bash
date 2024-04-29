# shellcheck disable=SC2154 shell=bash

# shellcheck disable=SC2034
setup() {
    . /usr/lib/bkctld/includes

    rm -f /root/bkctld.key*
    ssh-keygen -t rsa -N "" -f /root/bkctld.key -q

    set_variable "/etc/default/bkctld" "BACKUP_DISK" "/dev/vdb"

    JAILNAME=$(random_jail_name)
    JAILPATH="/backup/jails/${JAILNAME}"
    INCSPATH="/backup/incs/${JAILNAME}"
    ARCHIVEPATH="/backup/archives/${JAILNAME}"
    GLACIERPATH="/backup/glacier/${JAILNAME}"
    PORT=$(random_port)
    INC_NAME=$(inc_name_today)

    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
}

teardown() {
    remove_variable "/etc/default/bkctld" "BACKUP_DISK"
    FORCE=1 /usr/lib/bkctld/bkctld-remove "${JAILNAME}" \
      && rm -rf "${INCSPATH}" "/etc/evobackup/${JAILNAME}" "/etc/evobackup/${JAILNAME}.d"
}

random_jail_name() {
    tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1
}
random_port() {
    awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'
}
inc_name_today() {
    date +"%Y-%m-%d-%H"
}

set_variable() {
    file=${1:?}
    var_name=${2:?}
    var_value=${3:-}

    if grep -qE "^\s*${var_name}=" "${file}"; then
        sed --follow-symlinks --in-place "s|^\s*${var_name}=.*|${var_name}=${var_value}|" "${file}"
    else
        echo "${var_name}=${var_value}" >> "${file}"
    fi
}
remove_variable() {
    file=${1:?}
    var_name=${2:?}

    sed --follow-symlinks --in-place "s|^\s*${var_name}=.*|d" "${file}"
}

is_btrfs() {
    path=$1

    inode=$(stat --format=%i "${path}")

    test ${inode} -eq 256
}

flunk() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "$@"
    fi
  } >&2
  return 1
}

assert_success() {
  if [ "$status" -ne 0 ]; then
    flunk "command failed with exit status $status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

assert_failure() {
  if [ "$status" -eq 0 ]; then
    flunk "expected failed exit status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    { echo "expected: $1"
      echo "actual:   $2"
    } | flunk
  fi
}

refute_equal() {
  if [ "$1" = "$2" ]; then
    echo "expected $1 to not be equal to $2" | flunk
  fi
}

assert_output() {
  local expected
  if [ $# -eq 0 ]; then expected="$(cat -)"
  else expected="$1"
  fi
  assert_equal "$expected" "$output"
}

assert_line() {
  if [ "$1" -ge 0 ] 2>/dev/null; then
    assert_equal "$2" "${lines[$1]}"
  else
    local line
    for line in "${lines[@]}"; do
      if [ "$line" = "$1" ]; then return 0; fi
    done
    flunk "expected line \`$1'"
  fi
}

refute_line() {
  if [ "$1" -ge 0 ] 2>/dev/null; then
    local num_lines="${#lines[@]}"
    if [ "$1" -lt "$num_lines" ]; then
      flunk "output has $num_lines lines"
    fi
  else
    local line
    for line in "${lines[@]}"; do
      if [ "$line" = "$1" ]; then
        flunk "expected to not find line \`$line'"
      fi
    done
  fi
}

# shellcheck disable=SC2145
assert() {
  if ! "$@"; then
    flunk "failed: $@"
  fi
}
