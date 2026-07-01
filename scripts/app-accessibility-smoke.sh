#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility smoke: %s\n' "$1" >&2
  exit 1
}

command -v osascript >/dev/null 2>&1 || fail "missing dependency: osascript"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
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

expect_dump_contains() {
  local scenario="$1"
  local dump="$2"
  local needle="$3"

  printf '%s\n' "$dump" | rg --fixed-strings --quiet -- "$needle" ||
    fail "$scenario accessibility tree is missing expected text: $needle"
}

dump_accessibility_tree() {
  local pid="$1"
  local readiness_needle="$2"

  osascript - "$pid" "$readiness_needle" <<'APPLESCRIPT'
on collectText(target)
  set output to ""
  tell application "System Events"
    try
      set output to output & (name of target as text) & linefeed
    end try
    try
      set output to output & (description of target as text) & linefeed
    end try
    try
      set output to output & (value of target as text) & linefeed
    end try
    try
      set childElements to UI elements of target
      repeat with childElement in childElements
        set output to output & my collectText(childElement)
      end repeat
    end try
  end tell
  return output
end collectText

on collectWindows(targetProcess)
  set output to ""
  tell application "System Events"
    try
      set targetWindows to windows of targetProcess
      repeat with targetWindow in targetWindows
        set output to output & my collectText(targetWindow)
      end repeat
    end try
  end tell
  return output
end collectWindows

on run argv
  set targetPID to item 1 of argv as integer
  set readinessNeedle to item 2 of argv as text
  set targetProcess to missing value
  set axDump to ""

  tell application "System Events"
    repeat 40 times
      try
        set targetProcess to first application process whose unix id is targetPID
        exit repeat
      end try
      delay 0.25
    end repeat

    if targetProcess is missing value then
      error "missing app process"
    end if

    repeat 40 times
      if exists window 1 of targetProcess then
        exit repeat
      end if
      delay 0.25
    end repeat

    if not (exists window 1 of targetProcess) then
      error "missing app window"
    end if

    set frontmost of targetProcess to true

    repeat 40 times
      set axDump to my collectWindows(targetProcess)
      if readinessNeedle is "" or axDump contains readinessNeedle then
        return axDump
      end if
      delay 0.25
    end repeat

    return axDump
  end tell
end run
APPLESCRIPT
}

run_scenario() {
  local scenario="$1"
  shift

  KEYDEX_APP_WINDOW_PRESET=default KEYDEX_APP_SCREEN_SCENARIO="$scenario" swift run KeydexApp &
  app_pid="$!"

  local readiness_needle=""
  for needle in "$@"; do
    readiness_needle="$needle"
  done

  local ax_dump
  ax_dump="$(dump_accessibility_tree "$app_pid" "$readiness_needle")"
  cleanup

  for needle in "$@"; do
    expect_dump_contains "$scenario" "$ax_dump" "$needle"
  done

  printf 'accessibility_smoke=%s\n' "$scenario"
}

ui_elements_enabled="$(osascript -e 'tell application "System Events" to get UI elements enabled')"
[[ "$ui_elements_enabled" == "true" ]] ||
  fail "macOS accessibility UI scripting is disabled"

swift build --product KeydexApp

run_scenario inspector \
  "Credential scopes" \
  "Credential inventory table" \
  "Credential repair queue" \
  "Credential inspector" \
  "missing-keychain-item" \
  "plaintext-fallback" \
  "duplicate"

run_scenario settings \
  "Credential scopes" \
  "Credential inventory table" \
  "Keydex settings" \
  "Settings section" \
  "Keychain" \
  "Enabled for inventory scan runs" \
  "Enable keychain access" \
  "Request runtime keychain prompt"

run_scenario settings-appearance \
  "Keydex settings" \
  "Settings section" \
  "Appearance" \
  "Display mode" \
  "Cards" \
  "System light/dark"

echo "app accessibility smoke clean"
