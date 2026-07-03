#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app screen evidence: %s\n' "$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v screencapture >/dev/null 2>&1 || fail "missing dependency: screencapture"
command -v sips >/dev/null 2>&1 || fail "missing dependency: sips"
command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

git_dirty_state() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}

image_dimension() {
  local path="$1"
  local key="$2"
  local value

  value="$(sips -g "$key" "$path" | awk -F': ' -v key="$key" '$1 ~ key { print $2 }')"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "unable to read $key from screenshot: $path"
  printf '%s' "$value"
}

window_geometry() {
  local report="$1"

  printf '%s' "${report#window=* }"
}

window_stability_geometry() {
  local report="$1"
  local window_pattern='width=([0-9]+) height=([0-9]+)'

  [[ "$report" =~ $window_pattern ]] ||
    fail "unable to read stable window size from report: $report"
  printf 'width=%s height=%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

window_matches_expected_preset() {
  local geometry="$1"
  local preset="$2"
  local geometry_pattern='width=([0-9]+) height=([0-9]+)'
  local width
  local height

  [[ "$geometry" =~ $geometry_pattern ]] ||
    fail "unable to read window size from geometry: $geometry"
  width="${BASH_REMATCH[1]}"
  height="${BASH_REMATCH[2]}"

  case "$preset" in
    default)
      [[ "$width" == "1080" && "$height" == "680" ]]
      ;;
    compact)
      [[ "$width" -ge 900 && "$height" == "620" ]]
      ;;
    *)
      fail "unknown window preset for screen evidence: $preset"
      ;;
  esac
}

expected_window_description() {
  local preset="$1"

  case "$preset" in
    default)
      printf 'width=1080 height=680'
      ;;
    compact)
      printf 'width>=900 height=620'
      ;;
    *)
      fail "unknown window preset for screen evidence: $preset"
      ;;
  esac
}

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
  keydex_list_evidence_scenarios
}

scenario="${1:-default-window}"
window_selector="main"

if [[ "$scenario" == "--list" ]]; then
  list_scenarios
  exit 0
fi

inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" ||
  fail "unknown screen evidence scenario: $scenario. Supported scenarios: $(keydex_supported_evidence_scenarios)"
window_preset="$(keydex_evidence_window_preset "$scenario")" ||
  fail "unknown screen evidence scenario: $scenario. Supported scenarios: $(keydex_supported_evidence_scenarios)"

output_dir="${KEYDEX_SCREEN_EVIDENCE_DIR:-tmp/screen-evidence}"
mkdir -p "$output_dir"

swift build --product KeydexApp
bin_dir="$(swift build --show-bin-path)"
app_binary="$bin_dir/KeydexApp"
test -x "$app_binary" || fail "missing built app binary: $app_binary"

KEYDEX_APP_INVENTORY_MODE="$inventory_mode" \
  KEYDEX_APP_SCREEN_SCENARIO="$scenario" \
  KEYDEX_APP_WINDOW_PRESET="$window_preset" \
  "$app_binary" &
app_pid="$!"

cleanup() {
  kill "$app_pid" >/dev/null 2>&1 || true
  wait "$app_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

report=""
previous_geometry=""
expected_geometry="$(expected_window_description "$window_preset")"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if current_report="$(window_report "$app_pid" "$window_selector")"; then
    current_geometry="$(window_stability_geometry "$current_report")"
    if ! window_matches_expected_preset "$current_geometry" "$window_preset"; then
      previous_geometry=""
      sleep 1
      continue
    fi
    if [[ "$current_geometry" == "$previous_geometry" ]] && ((attempt >= 5)); then
      report="$current_report"
      break
    fi
    previous_geometry="$current_geometry"
  fi
  sleep 1
done

test -n "$report" ||
  fail "KeydexApp did not publish a stable $expected_geometry window for $scenario"

window_id="${report#window=}"
window_id="${window_id%% *}"
capture_path="$output_dir/$scenario.png"
manifest_path="$output_dir/$scenario.manifest"

if ! screencapture -x -l "$window_id" "$capture_path"; then
  fail "screencapture failed for $report. Grant Screen Recording permission to the Codex host or terminal, then rerun."
fi

test -s "$capture_path" || fail "empty screenshot artifact: $capture_path"

pixel_width="$(image_dimension "$capture_path" pixelWidth)"
pixel_height="$(image_dimension "$capture_path" pixelHeight)"

{
  printf 'scenario=%s\n' "$scenario"
  printf 'inventory_mode=%s\n' "$inventory_mode"
  printf 'window_preset=%s\n' "$window_preset"
  printf 'captured_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'git_sha=%s\n' "$(git rev-parse --short HEAD)"
  printf 'git_dirty=%s\n' "$(git_dirty_state)"
  printf '%s\n' "$report"
  printf 'screenshot=%s\n' "$capture_path"
  printf 'screenshot_pixel_width=%s\n' "$pixel_width"
  printf 'screenshot_pixel_height=%s\n' "$pixel_height"
} >"$manifest_path"

printf '%s\n' "$report"
printf 'screenshot=%s\n' "$capture_path"
printf 'manifest=%s\n' "$manifest_path"
echo "app screen evidence clean"
