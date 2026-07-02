#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence review: %s\n' "$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

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
  expect_manifest_key "$manifest_path" reviewed_at
  expect_manifest_key "$manifest_path" reviewer

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
head_dirty="$(git_dirty_state)"

review_scenario default-window
review_scenario card-view
review_scenario card-detail
review_scenario empty-inventory
review_scenario search-filter
review_scenario inspector
review_scenario settings
review_scenario settings-appearance
review_scenario settings-sources
review_scenario settings-paths
review_scenario settings-tags
review_scenario settings-rules
review_scenario compact-window

echo "app accessibility evidence review clean"
