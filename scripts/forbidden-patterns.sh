#!/usr/bin/env bash
set -euo pipefail

status=0

check() {
  local label="$1"
  local pattern="$2"
  shift 2

  if rg --line-number --hidden --glob '!/.git/**' --glob '!/.build/**' "$pattern" "$@"; then
    printf 'forbidden pattern: %s\n' "$label" >&2
    status=1
  fi
}

check 'silent try?' 'try\?' Sources Tests Apps
check 'empty catch' 'catch[[:space:]]*\{[[:space:]]*\}' Sources Tests Apps
check 'force unwrap' '![[:space:]]*(\.|,|\)|$)' Sources Tests Apps
check 'secret column name' '(secret_value|password_value|token_value)' Sources Tests Apps docs

exit "$status"
