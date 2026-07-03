#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence review: %s\n' "$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

git_dirty_state() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

expect_notes_context() {
  local scenario="$1"
  local notes_path="$2"
  local focus
  local inventory_mode
  local window_preset
  local target

  focus="$(keydex_evidence_accessibility_focus "$scenario")" ||
    fail "missing accessibility focus for scenario: $scenario"
  inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" ||
    fail "missing inventory mode for scenario: $scenario"
  window_preset="$(keydex_evidence_window_preset "$scenario")" ||
    fail "missing window preset for scenario: $scenario"

  expect_file_contains "$notes_path" "## Scenario Focus"
  expect_file_contains "$notes_path" "Focus: $focus"
  expect_file_contains "$notes_path" "Inventory mode: $inventory_mode"
  expect_file_contains "$notes_path" "Window preset: $window_preset"
  expect_file_contains "$notes_path" "Review targets:"

  while IFS= read -r target; do
    expect_file_contains "$notes_path" "$target"
  done < <(keydex_evidence_accessibility_targets "$scenario")
}

expect_manifest_value() {
  local path="$1"
  local key="$2"
  local value="$3"

  rg --fixed-strings --line-regexp --quiet -- "$key=$value" "$path" ||
    fail "$path is missing expected manifest value: $key=$value"
}

expect_manifest_key() {
  local path="$1"
  local key="$2"

  rg --quiet "^${key}=" "$path" ||
    fail "$path is missing expected manifest key: $key"
}

manifest_value() {
  local path="$1"
  local key="$2"
  local line

  line="$(rg --line-regexp --only-matching "${key}=.*" "$path" || true)"
  [[ -n "$line" ]] || return 1
  printf '%s' "${line#*=}"
}

expect_manifest_review_value() {
  local path="$1"
  local key="$2"
  local template_value="$3"
  local value

  value="$(manifest_value "$path" "$key")" ||
    fail "$path is missing expected manifest key: $key"
  [[ -n "$value" ]] ||
    fail "$path has empty review audit value: $key"
  [[ "$value" != "$template_value" ]] ||
    fail "$path still has template review audit value: $key=$template_value"
}

review_scenario() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"

  test -f "$manifest_path" || fail "missing manifest: $manifest_path"
  test -s "$notes_path" || fail "missing notes: $notes_path"

  expect_manifest_value "$manifest_path" scenario "$scenario"
  expect_manifest_value "$manifest_path" git_sha "$head_sha"
  expect_manifest_value "$manifest_path" git_dirty "$head_dirty"
  expect_manifest_value "$manifest_path" voiceover pass
  expect_manifest_value "$manifest_path" keyboard pass
  expect_manifest_value "$manifest_path" state_not_color_only pass
  expect_manifest_value "$manifest_path" dynamic_type pass
  expect_manifest_value "$manifest_path" notes "$notes_path"
  expect_manifest_review_value "$manifest_path" reviewed_at "<ISO-8601 timestamp>"
  expect_manifest_review_value "$manifest_path" reviewer "<name or handle>"

  expect_file_contains "$notes_path" "# Accessibility Evidence: $scenario"
  expect_file_contains "$notes_path" "VoiceOver"
  expect_file_contains "$notes_path" "Keyboard"
  expect_file_contains "$notes_path" "State Not Color Only"
  expect_file_contains "$notes_path" "Dynamic Type"
  expect_file_contains "$notes_path" "Open Issues"
  expect_notes_context "$scenario" "$notes_path"

  printf 'reviewed=%s\n' "$scenario"
}

evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  review_scenario "$scenario"
done

echo "app accessibility evidence review clean"
