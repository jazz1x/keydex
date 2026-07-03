#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility smoke: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

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

expect_dump_not_contains() {
  local scenario="$1"
  local dump="$2"
  local needle="$3"

  if printf '%s\n' "$dump" | rg --fixed-strings --quiet -- "$needle"; then
    fail "$scenario accessibility tree exposes hidden text: $needle"
  fi
}

dump_accessibility_tree() {
  local pid="$1"
  local readiness_needle="$2"

  swift -e '
import ApplicationServices
import Foundation

guard CommandLine.arguments.count >= 3,
  let pid = pid_t(CommandLine.arguments[1])
else {
  fputs("app accessibility smoke: invalid pid argument\n", stderr)
  exit(2)
}

let readinessNeedle = CommandLine.arguments[2]
let app = AXUIElementCreateApplication(pid)
let maxAXReadinessAttempts = 40
let axReadinessPollInterval: TimeInterval = 0.25

// AX can publish the app process before its window tree is readable.
// The smoke waits only for that observable readiness state; missing windows still fail.
func attribute(_ name: String, from element: AXUIElement) -> AnyObject? {
  var value: AnyObject?
  let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  guard result == .success else { return nil }
  return value
}

func textValue(_ value: AnyObject) -> String? {
  if let string = value as? String {
    return string.isEmpty ? nil : string
  }

  if let number = value as? NSNumber {
    return number.stringValue
  }

  return nil
}

func collectText(from element: AXUIElement) -> String {
  var output = ""
  let textAttributes = [
    kAXTitleAttribute,
    kAXDescriptionAttribute,
    kAXValueAttribute,
    kAXHelpAttribute,
    kAXRoleAttribute,
    kAXSubroleAttribute,
  ]

  for attributeName in textAttributes {
    if let value = attribute(attributeName, from: element), let text = textValue(value) {
      output += text + "\n"
    }
  }

  if let children = attribute(kAXChildrenAttribute, from: element) as? [AXUIElement] {
    for child in children {
      output += collectText(from: child)
    }
  }

  return output
}

func collectWindows() -> String {
  guard let windows = attribute(kAXWindowsAttribute, from: app) as? [AXUIElement], !windows.isEmpty else {
    return ""
  }

  return windows.map { collectText(from: $0) }.joined(separator: "\n")
}

for _ in 0..<maxAXReadinessAttempts {
  let dump = collectWindows()
  if !dump.isEmpty, readinessNeedle.isEmpty || dump.contains(readinessNeedle) {
    print(dump)
    exit(0)
  }
  Thread.sleep(forTimeInterval: axReadinessPollInterval)
}

let finalDump = collectWindows()
if finalDump.isEmpty {
  fputs("missing app window\n", stderr)
  exit(2)
}

print(finalDump)
' "$pid" "$readiness_needle"
}

run_scenario() {
  local scenario="$1"
  shift
  local inventory_mode
  local window_preset
  local -a expected_needles=()
  local -a hidden_needles=()
  local hidden_mode=false
  local needle

  while (($#)); do
    if [[ "$1" == "--not" ]]; then
      hidden_mode=true
      shift
      continue
    fi

    if [[ "$hidden_mode" == true ]]; then
      hidden_needles+=("$1")
    else
      expected_needles+=("$1")
    fi
    shift
  done

  inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" ||
    fail "missing inventory mode for scenario: $scenario"
  window_preset="$(keydex_evidence_window_preset "$scenario")" ||
    fail "missing window preset for scenario: $scenario"

  printf 'accessibility_smoke_start=%s inventory_mode=%s window_preset=%s\n' \
    "$scenario" \
    "$inventory_mode" \
    "$window_preset"

  KEYDEX_APP_INVENTORY_MODE="$inventory_mode" \
    KEYDEX_APP_WINDOW_PRESET="$window_preset" \
    KEYDEX_APP_SCREEN_SCENARIO="$scenario" \
    "$app_binary" &
  app_pid="$!"
  printf 'accessibility_smoke_pid=%s scenario=%s\n' "$app_pid" "$scenario"

  local readiness_needle=""
  if ((${#expected_needles[@]})); then
    for needle in "${expected_needles[@]}"; do
      readiness_needle="$needle"
    done
  fi

  local ax_dump
  ax_dump="$(dump_accessibility_tree "$app_pid" "$readiness_needle")"
  cleanup
  printf 'accessibility_smoke_checked=%s expected=%s hidden=%s\n' \
    "$scenario" \
    "${#expected_needles[@]}" \
    "${#hidden_needles[@]}"

  if ((${#expected_needles[@]})); then
    for needle in "${expected_needles[@]}"; do
      expect_dump_contains "$scenario" "$ax_dump" "$needle"
    done
  fi

  if ((${#hidden_needles[@]})); then
    for needle in "${hidden_needles[@]}"; do
      expect_dump_not_contains "$scenario" "$ax_dump" "$needle"
    done
  fi

  printf 'accessibility_smoke=%s\n' "$scenario"
}

swift -e 'import ApplicationServices; import Foundation; exit(AXIsProcessTrusted() ? 0 : 1)' ||
  fail "macOS accessibility permission is not trusted for this host"

swift build --product KeydexApp
bin_dir="$(swift build --show-bin-path)"
app_binary="$bin_dir/KeydexApp"
test -x "$app_binary" || fail "missing built app binary: $app_binary"

run_scenario default-window \
  "Credential scopes" \
  "Credential inventory cards" \
  "Credential Library" \
  "github" \
  "missing-keychain-item" \
  "Credential repair queue"

run_scenario card-view \
  "Credential scopes" \
  "Credential inventory cards" \
  "Credential Library" \
  "aws" \
  "missing-keychain-item" \
  "Credential repair queue"

run_scenario card-detail \
  "Credential card detail" \
  "Credential Library" \
  "aws" \
  "missing-keychain-item" \
  "Manage Keychain reference" \
  "Manage credential tags" \
  "Choose custom artwork" \
  "Sources" \
  "AWS_ACCESS_KEY_ID"

run_scenario empty-inventory \
  "Credential scopes" \
  "Credential inventory table" \
  "Empty credential inventory state"

run_scenario search-filter \
  "Credential scopes" \
  "Search credentials" \
  "Search results for github" \
  "1 results" \
  "github" \
  "plaintext-fallback" \
  "Credential inventory table"

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
  "Settings" \
  "Settings section" \
  "Keychain" \
  "Enabled for inventory scan runs" \
  "Enable keychain access" \
  "Request runtime keychain prompt" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario settings-appearance \
  "Settings" \
  "Settings section" \
  "Appearance" \
  "Display mode" \
  "Cards" \
  "System light/dark" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario settings-sources \
  "Settings" \
  "Settings section" \
  "Sources" \
  "Scan Sources" \
  "Shell profiles" \
  "Environment variables" \
  "Config files" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario settings-paths \
  "Settings" \
  "Settings section" \
  "Paths" \
  "Scan Paths" \
  "/Users/example/.zshrc" \
  "/Users/example/.aws/credentials" \
  "Add scan path" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario settings-tags \
  "Settings" \
  "Settings section" \
  "Tags" \
  "Credential Tags" \
  "Rotates Soon" \
  "Tag color" \
  "Add tag" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario settings-rules \
  "Settings" \
  "Settings section" \
  "Rules" \
  "Ignored Sources" \
  "Unmanaged Sources" \
  "~/Downloads/keys/legacy.env" \
  "process:local-session-secret" \
  --not \
  "Register Keychain reference" \
  "Open settings" \
  "Inventory and display controls"

run_scenario compact-window \
  "Credential scopes" \
  "Credential inventory table" \
  "Credential repair queue" \
  "aws" \
  "missing-keychain-item"

echo "app accessibility smoke clean"
