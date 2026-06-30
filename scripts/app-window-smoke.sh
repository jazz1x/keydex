#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app window smoke: %s\n' "$1" >&2
  exit 1
}

window_report() {
  local pid="$1"

  swift -e '
    import CoreGraphics
    import Foundation

    let pid = Int(CommandLine.arguments[1])!
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
      as? [[String: Any]] ?? []
    var selectedReport: String?
    var selectedArea = 0

    for window in windows {
      guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int, ownerPID == pid else {
        continue
      }

      guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else {
        continue
      }

      guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let width = bounds["Width"] as? Int,
        let height = bounds["Height"] as? Int,
        let number = window[kCGWindowNumber as String] as? Int
      else {
        continue
      }

      let report = "window=\(number) width=\(width) height=\(height)"
      let area = width * height

      if area > selectedArea {
        selectedArea = area
        selectedReport = report
      }
    }

    if let selectedReport {
      print(selectedReport)
      exit(0)
    }

    exit(2)
  ' "$pid"
}

swift build --product KeydexApp

KEYDEX_APP_WINDOW_PRESET=default swift run KeydexApp &
app_pid="$!"
trap 'kill "$app_pid" >/dev/null 2>&1 || true' EXIT

report=""
previous_report=""
for attempt in 1 2 3 4 5; do
  if current_report="$(window_report "$app_pid")"; then
    if [[ "$current_report" == "$previous_report" ]] && ((attempt >= 5)); then
      report="$current_report"
      break
    fi
    previous_report="$current_report"
  fi
  sleep 1
done

test -n "$report" || fail "KeydexApp did not publish a stable on-screen window"
printf '%s\n' "$report"

echo "app window smoke clean"
