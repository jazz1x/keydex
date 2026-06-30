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

swift build --product KeydexApp

swift run KeydexApp &
app_pid="$!"
trap 'kill "$app_pid" >/dev/null 2>&1 || true' EXIT

report=""
for _ in 1 2 3 4 5; do
  if report="$(window_report "$app_pid")"; then
    break
  fi
  sleep 1
done

test -n "$report" || fail "KeydexApp did not publish an on-screen window"
printf '%s\n' "$report"

case "$report" in
  *"width=1080 height=680"*) ;;
  *) fail "unexpected default window size: $report" ;;
esac

echo "app window smoke clean"
