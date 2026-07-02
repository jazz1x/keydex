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
  local selector="$2"

  swift -e '
    import CoreGraphics
    import Foundation

    let pid = Int(CommandLine.arguments[1])!
    let selector = CommandLine.arguments[2]
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
      as? [[String: Any]] ?? []

    var selectedReport: String?
    var selectedArea = selector == "settings" ? Int.max : 0

    for window in windows {
      guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int, ownerPID == pid else {
        continue
      }

      guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else {
        continue
      }

      guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let x = bounds["X"] as? Int,
        let y = bounds["Y"] as? Int,
        let width = bounds["Width"] as? Int,
        let height = bounds["Height"] as? Int,
        let number = window[kCGWindowNumber as String] as? Int
      else {
        continue
      }

      let report = "window=\(number) x=\(x) y=\(y) width=\(width) height=\(height)"
      let area = width * height

      if selector == "settings" {
        if area < selectedArea {
          selectedArea = area
          selectedReport = report
        }
      } else if area > selectedArea {
        selectedArea = area
        selectedReport = report
      }
    }

    if let selectedReport {
      print(selectedReport)
      exit(0)
    }

    exit(2)
  ' "$pid" "$selector"
}

list_scenarios() {
  printf '%s\n' \
    default-window \
    card-view \
    card-detail \
    empty-inventory \
    search-filter \
    inspector \
    settings \
    settings-appearance \
    settings-sources \
    settings-paths \
    settings-tags \
    settings-rules \
    compact-window
}

scenario="${1:-default-window}"
inventory_mode="sample"
window_preset="default"
window_selector="main"

if [[ "$scenario" == "--list" ]]; then
  list_scenarios
  exit 0
fi

case "$scenario" in
  default-window)
    inventory_mode="sample"
    ;;
  card-view)
    inventory_mode="sample"
    ;;
  card-detail)
    inventory_mode="sample"
    ;;
  empty-inventory)
    inventory_mode="empty"
    ;;
  search-filter | inspector)
    inventory_mode="sample"
    ;;
  settings | settings-appearance | settings-sources | settings-paths | settings-tags | settings-rules)
    inventory_mode="sample"
    ;;
  compact-window)
    inventory_mode="sample"
    window_preset="compact"
    ;;
  *)
    fail "unknown screen evidence scenario: $scenario. Supported scenarios: default-window, card-view, card-detail, empty-inventory, search-filter, inspector, settings, settings-appearance, settings-sources, settings-paths, settings-tags, settings-rules, compact-window"
    ;;
esac

output_dir="${KEYDEX_SCREEN_EVIDENCE_DIR:-tmp/screen-evidence}"
mkdir -p "$output_dir"

swift build --product KeydexApp
bin_dir="$(swift build --show-bin-path)"
app_binary="$bin_dir/KeydexApp"
test -x "$app_binary" || fail "missing built app binary: $app_binary"

if [[ "$window_preset" == "compact" ]]; then
  KEYDEX_APP_INVENTORY_MODE="$inventory_mode" \
    KEYDEX_APP_SCREEN_SCENARIO="$scenario" \
    KEYDEX_APP_WINDOW_PRESET="$window_preset" \
    "$app_binary" &
else
  KEYDEX_APP_INVENTORY_MODE="$inventory_mode" \
    KEYDEX_APP_SCREEN_SCENARIO="$scenario" \
    "$app_binary" &
fi
app_pid="$!"

cleanup() {
  if kill -0 "$app_pid" >/dev/null 2>&1; then
    kill "$app_pid"
  fi
}
trap cleanup EXIT

report=""
previous_report=""
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if current_report="$(window_report "$app_pid" "$window_selector")"; then
    if [[ "$current_report" == "$previous_report" ]] && ((attempt >= 5)); then
      report="$current_report"
      break
    fi
    previous_report="$current_report"
  fi
  sleep 1
done

test -n "$report" || fail "KeydexApp did not publish a stable on-screen window for $scenario"

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
