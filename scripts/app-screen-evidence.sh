#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app screen evidence: %s\n' "$1" >&2
  exit 1
}

command -v screencapture >/dev/null 2>&1 || fail "missing dependency: screencapture"
command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"

window_report() {
  local pid="$1"

  swift -e '
    import CoreGraphics
    import Foundation

    let pid = Int(CommandLine.arguments[1])!
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
      as? [[String: Any]] ?? []

    for window in windows {
      guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int, ownerPID == pid else {
        continue
      }

      guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let width = bounds["Width"] as? Int,
        let height = bounds["Height"] as? Int,
        let number = window[kCGWindowNumber as String] as? Int
      else {
        continue
      }

      print("window=\(number) width=\(width) height=\(height)")
      exit(0)
    }

    exit(2)
  ' "$pid"
}

list_scenarios() {
  printf '%s\n' \
    default-window \
    empty-inventory \
    search-filter \
    inspector \
    settings \
    compact-window
}

scenario="${1:-default-window}"
inventory_mode="sample"
window_preset="default"

if [[ "$scenario" == "--list" ]]; then
  list_scenarios
  exit 0
fi

case "$scenario" in
  default-window)
    inventory_mode="sample"
    ;;
  empty-inventory)
    inventory_mode="empty"
    ;;
  search-filter | inspector | settings)
    inventory_mode="sample"
    ;;
  compact-window)
    inventory_mode="sample"
    window_preset="compact"
    ;;
  *)
    fail "unknown screen evidence scenario: $scenario. Supported scenarios: default-window, empty-inventory, search-filter, inspector, settings, compact-window"
    ;;
esac

output_dir="${KEYDEX_SCREEN_EVIDENCE_DIR:-tmp/screen-evidence}"
mkdir -p "$output_dir"

swift build --product KeydexApp

KEYDEX_APP_INVENTORY_MODE="$inventory_mode" \
  KEYDEX_APP_SCREEN_SCENARIO="$scenario" \
  KEYDEX_APP_WINDOW_PRESET="$window_preset" \
  swift run KeydexApp &
app_pid="$!"

cleanup() {
  if kill -0 "$app_pid" >/dev/null 2>&1; then
    kill "$app_pid"
  fi
}
trap cleanup EXIT

report=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if report="$(window_report "$app_pid")"; then
    break
  fi
  sleep 1
done

test -n "$report" || fail "KeydexApp did not publish an on-screen window"

window_id="${report#window=}"
window_id="${window_id%% *}"
capture_path="$output_dir/$scenario.png"
manifest_path="$output_dir/$scenario.manifest"

if ! screencapture -x -l "$window_id" "$capture_path"; then
  fail "screencapture failed for $report. Grant Screen Recording permission to the Codex host or terminal, then rerun."
fi

test -s "$capture_path" || fail "empty screenshot artifact: $capture_path"

{
  printf 'scenario=%s\n' "$scenario"
  printf 'inventory_mode=%s\n' "$inventory_mode"
  printf 'window_preset=%s\n' "$window_preset"
  printf 'captured_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'git_sha=%s\n' "$(git rev-parse --short HEAD)"
  printf '%s\n' "$report"
  printf 'screenshot=%s\n' "$capture_path"
} >"$manifest_path"

printf '%s\n' "$report"
printf 'screenshot=%s\n' "$capture_path"
printf 'manifest=%s\n' "$manifest_path"
echo "app screen evidence clean"
