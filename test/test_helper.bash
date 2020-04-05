
setup() {
    . /usr/lib/bkctld/includes

    rm -f /root/bkctld.key*
    ssh-keygen -t rsa -N "" -f /root/bkctld.key -q

    grep -qE "^BACKUP_DISK=" /etc/default/bkctld || echo "BACKUP_DISK=/dev/vdb" >> /etc/default/bkctld

    JAILNAME=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w15 | head -n1)
    JAILPATH="/backup/jails/${JAILNAME}"
    INCSPATH="/backup/incs/${JAILNAME}"
    PORT=$(awk -v min=2222 -v max=2999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    INC_NAME=$(date +"%Y-%m-%d-%H")

    inode=$(stat --format=%i /backup)

    /usr/lib/bkctld/bkctld-init "${JAILNAME}"
}

teardown() {
    /usr/lib/bkctld/bkctld-remove "${JAILNAME}" && rm -rf "${INCSPATH}"
}

is_btrfs() {
    path=$1

    inode=$(stat --format=%i "${path}")

    test $inode -eq 256
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

assert() {
  if ! "$@"; then
    flunk "failed: $@"
  fi
}
