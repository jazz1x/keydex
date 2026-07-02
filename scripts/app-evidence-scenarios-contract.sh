#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app evidence scenarios contract: %s\n' "$1" >&2
  exit 1
}

command -v swift >/dev/null 2>&1 || fail "missing dependency: swift"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

app_source="Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift"
accessibility_smoke_script="scripts/app-accessibility-smoke.sh"
screen_doc="docs/SCREEN-VALIDATION.md"
validation_doc="docs/VALIDATION-SCENARIOS.md"
release_candidate_doc="docs/RELEASE-CANDIDATE.md"
test -f "$app_source" || fail "missing app presentation model: $app_source"
test -f "$accessibility_smoke_script" || fail "missing accessibility smoke script: $accessibility_smoke_script"
test -f "$screen_doc" || fail "missing screen validation doc: $screen_doc"
test -f "$validation_doc" || fail "missing validation scenarios doc: $validation_doc"
test -f "$release_candidate_doc" || fail "missing release candidate doc: $release_candidate_doc"

expected_scenarios="$(keydex_list_evidence_scenarios)"
listed_scenarios="$("$script_dir/app-screen-evidence.sh" --list)"

if [[ "$listed_scenarios" != "$expected_scenarios" ]]; then
  fail "app-screen-evidence --list drifted from KEYDEX_EVIDENCE_SCENARIOS"
fi

if keydex_is_evidence_scenario "missing-scenario"; then
  fail "unknown evidence scenario must not resolve as supported"
fi

if keydex_evidence_inventory_mode "missing-scenario" >/dev/null; then
  fail "unknown evidence scenario must not resolve to an inventory mode"
fi

if keydex_evidence_window_preset "missing-scenario" >/dev/null; then
  fail "unknown evidence scenario must not resolve to a window preset"
fi

app_scenarios_path="$(mktemp "${TMPDIR:-/tmp}/keydex-app-scenarios.XXXXXX")"
swift - "$app_source" >"$app_scenarios_path" <<'SWIFT'
import Foundation

let sourcePath = CommandLine.arguments[1]
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
var inScenarioEnum = false
var rawValues: [String] = []

func trimmed(_ value: Substring) -> String {
  value.trimmingCharacters(in: .whitespacesAndNewlines)
}

func rawValue(from segment: Substring) -> String? {
  let parts = segment.split(separator: "=", maxSplits: 1)
  guard let identifier = parts.first?.split(whereSeparator: { $0.isWhitespace }).first else {
    return nil
  }

  if parts.count == 1 {
    return String(identifier)
  }

  let rhs = String(parts[1])
  let pattern = #""([^"]+)""#
  let regex = try! NSRegularExpression(pattern: pattern)
  let range = NSRange(rhs.startIndex..<rhs.endIndex, in: rhs)
  guard let match = regex.firstMatch(in: rhs, range: range),
    let rawRange = Range(match.range(at: 1), in: rhs)
  else {
    return nil
  }

  return String(rhs[rawRange])
}

for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
  let text = trimmed(line)

  if text.hasPrefix("enum AppScreenScenario:") {
    inScenarioEnum = true
    continue
  }

  guard inScenarioEnum else {
    continue
  }

  if text == "}" {
    break
  }

  guard text.hasPrefix("case ") else {
    continue
  }

  let cases = text.dropFirst("case ".count).split(separator: ",")
  for caseSegment in cases {
    if let value = rawValue(from: caseSegment) {
      rawValues.append(value)
    }
  }
}

if rawValues.isEmpty {
  fputs("app evidence scenarios contract: AppScreenScenario raw values were not found\n", stderr)
  exit(1)
}

print(rawValues.joined(separator: "\n"))
SWIFT

app_scenarios="$(<"$app_scenarios_path")"
rm -f "$app_scenarios_path"

if [[ "$app_scenarios" != "$expected_scenarios" ]]; then
  printf 'expected scenarios:\n%s\n' "$expected_scenarios" >&2
  printf 'app scenarios:\n%s\n' "$app_scenarios" >&2
  fail "AppScreenScenario raw values drifted from KEYDEX_EVIDENCE_SCENARIOS"
fi

accessibility_smoke_scenarios="$(
  awk '/^[[:space:]]*run_scenario[[:space:]]+/ { print $2 }' "$accessibility_smoke_script"
)"

if [[ -z "$accessibility_smoke_scenarios" ]]; then
  fail "$accessibility_smoke_script does not declare any run_scenario checks"
fi

while IFS= read -r scenario; do
  keydex_is_evidence_scenario "$scenario" ||
    fail "$accessibility_smoke_script references unsupported evidence scenario: $scenario"
done <<<"$accessibility_smoke_scenarios"

while IFS= read -r scenario; do
  inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" ||
    fail "missing inventory mode for scenario: $scenario"
  case "$inventory_mode" in
    sample | empty)
      ;;
    *)
      fail "unsupported inventory mode for scenario $scenario: $inventory_mode"
      ;;
  esac

  window_preset="$(keydex_evidence_window_preset "$scenario")" ||
    fail "missing window preset for scenario: $scenario"
  case "$window_preset" in
    default | compact)
      ;;
    *)
      fail "unsupported window preset for scenario $scenario: $window_preset"
      ;;
  esac

  if ! rg --fixed-strings --quiet -- "$scenario" "$screen_doc"; then
    fail "$screen_doc is missing required evidence scenario: $scenario"
  fi
done <<<"$expected_scenarios"

for needle in \
  "Runtime accessibility" \
  "scripts/app-accessibility-smoke.sh" \
  "scripts/app-evidence-scenarios.sh"; do
  if ! rg --fixed-strings --quiet -- "$needle" "$screen_doc"; then
    fail "$screen_doc is missing accessibility smoke scenario SSOT text: $needle"
  fi
done

for needle in \
  "scripts/app-evidence-scenarios.sh" \
  "scripts/app-screen-evidence.sh --list" \
  "make app-evidence-scenarios-contract" \
  "scenario has current screenshot and accessibility evidence"; do
  if ! rg --fixed-strings --quiet -- "$needle" "$validation_doc"; then
    fail "$validation_doc is missing scenario SSOT text: $needle"
  fi
done

if rg --fixed-strings --quiet -- "The first supported scenarios are" "$validation_doc"; then
  fail "$validation_doc must not name a partial first scenario set"
fi

for needle in \
  "scripts/app-evidence-scenarios.sh" \
  "make app-screen-evidence-review"; do
  if ! rg --fixed-strings --quiet -- "$needle" "$release_candidate_doc"; then
    fail "$release_candidate_doc is missing scenario SSOT text: $needle"
  fi
done

for stale_phrase in \
  "settings-section" \
  "default, empty, search, inspector"; do
  if rg --fixed-strings --quiet -- "$stale_phrase" "$release_candidate_doc"; then
    fail "$release_candidate_doc must not describe stale partial scenario sets: $stale_phrase"
  fi
done

echo "app evidence scenarios contract clean"
