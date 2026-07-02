#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app menubar smoke: %s\n' "$1" >&2
  exit 1
}

command -v osascript >/dev/null 2>&1 || fail "missing dependency: osascript"
command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"

app_pid=""

cleanup() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" >/dev/null 2>&1 || true
    app_pid=""
  fi
}

trap cleanup EXIT

ui_elements_enabled="$(osascript -e 'tell application "System Events" to get UI elements enabled')"
[[ "$ui_elements_enabled" == "true" ]] ||
  fail "macOS accessibility UI scripting is disabled"

swift build --product KeydexApp
bin_dir="$(swift build --show-bin-path)"
app_binary="$bin_dir/KeydexApp"
test -x "$app_binary" || fail "missing built app binary: $app_binary"

KEYDEX_APP_WINDOW_PRESET=default "$app_binary" &
app_pid="$!"

osascript - "$app_pid" <<'APPLESCRIPT'
on run argv
  set targetPID to item 1 of argv as integer
  set targetProcess to missing value

  tell application "System Events"
    repeat 40 times
      set matches to application processes whose unix id is targetPID
      if (count of matches) > 0 then
        set targetProcess to item 1 of matches
        exit repeat
      end if
      delay 0.25
    end repeat

    if targetProcess is missing value then
      error "missing app process"
    end if

    repeat 40 times
      if exists menu bar 2 of targetProcess then
        set statusNames to name of every menu bar item of menu bar 2 of targetProcess
        if statusNames contains "Keydex" then
          exit repeat
        end if
      end if
      delay 0.25
    end repeat

    if not (exists menu bar 2 of targetProcess) then
      error "missing status menu bar"
    end if

    set statusNames to name of every menu bar item of menu bar 2 of targetProcess
    if not (statusNames contains "Keydex") then
      error "missing Keydex menu bar item"
    end if

    set keydexItem to first menu bar item of menu bar 2 of targetProcess whose name is "Keydex"
    set itemDescription to description of keydexItem
    if itemDescription is not "status menu" then
      error "unexpected Keydex menu bar description: " & itemDescription
    end if

    click keydexItem
    delay 0.2

    set actionNames to name of every menu item of menu 1 of keydexItem
    if not (actionNames contains "Open Keydex") then
      error "missing Open Keydex menu action"
    end if

    if not (actionNames contains "Quit Keydex") then
      error "missing Quit Keydex menu action"
    end if
  end tell
end run
APPLESCRIPT

echo "app menubar smoke clean"
