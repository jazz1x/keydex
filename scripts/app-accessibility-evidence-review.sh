#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence review: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

review_scenario() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"

  test -f "$manifest_path" || fail "missing manifest: $manifest_path"
  test -s "$notes_path" || fail "missing notes: $notes_path"

  expect_file_contains "$manifest_path" "scenario=$scenario"
  expect_file_contains "$manifest_path" "git_sha=$head_sha"
  expect_file_contains "$manifest_path" "voiceover=pass"
  expect_file_contains "$manifest_path" "keyboard=pass"
  expect_file_contains "$manifest_path" "state_not_color_only=pass"
  expect_file_contains "$manifest_path" "dynamic_type=pass"
  expect_file_contains "$manifest_path" "notes=$notes_path"
  expect_file_contains "$manifest_path" "reviewed_at="
  expect_file_contains "$manifest_path" "reviewer="

  expect_file_contains "$notes_path" "# Accessibility Evidence: $scenario"
  expect_file_contains "$notes_path" "VoiceOver"
  expect_file_contains "$notes_path" "Keyboard"
  expect_file_contains "$notes_path" "State Not Color Only"
  expect_file_contains "$notes_path" "Dynamic Type"
  expect_file_contains "$notes_path" "Open Issues"

  printf 'reviewed=%s\n' "$scenario"
}

evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
head_sha="$(git rev-parse --short HEAD)"

review_scenario default-window
review_scenario empty-inventory
review_scenario search-filter
review_scenario inspector
review_scenario settings
review_scenario settings-sources
review_scenario settings-paths
review_scenario settings-rules
review_scenario compact-window

echo "app accessibility evidence review clean"
