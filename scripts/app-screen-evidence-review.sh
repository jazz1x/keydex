#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app screen evidence review: %s\n' "$1" >&2
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

review_scenario() {
  local scenario="$1"
  local inventory_mode="$2"
  local window_preset="$3"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local screenshot_path="$evidence_dir/$scenario.png"

  test -f "$manifest_path" || fail "missing manifest: $manifest_path"
  test -s "$screenshot_path" || fail "missing screenshot: $screenshot_path"

  expect_file_contains "$manifest_path" "scenario=$scenario"
  expect_file_contains "$manifest_path" "inventory_mode=$inventory_mode"
  expect_file_contains "$manifest_path" "window_preset=$window_preset"
  expect_file_contains "$manifest_path" "git_sha=$head_sha"
  expect_file_contains "$manifest_path" "git_dirty=$head_dirty"
  expect_file_contains "$manifest_path" "window="
  expect_file_contains "$manifest_path" "width="
  expect_file_contains "$manifest_path" "height="
  expect_file_contains "$manifest_path" "screenshot=$screenshot_path"
  expect_file_contains "$manifest_path" "captured_at="

  case "$scenario" in
    settings | settings-appearance | settings-sources | settings-paths | settings-tags | settings-rules)
      expect_file_contains "$manifest_path" "width=1080 height=680"
      ;;
  esac

  printf 'reviewed=%s\n' "$scenario"
}

evidence_dir="${KEYDEX_SCREEN_EVIDENCE_DIR:-tmp/screen-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

review_scenario default-window sample default
review_scenario card-view sample default
review_scenario card-detail sample default
review_scenario empty-inventory empty default
review_scenario search-filter sample default
review_scenario inspector sample default
review_scenario settings sample default
review_scenario settings-appearance sample default
review_scenario settings-sources sample default
review_scenario settings-paths sample default
review_scenario settings-tags sample default
review_scenario settings-rules sample default
review_scenario compact-window sample compact

echo "app screen evidence review clean"
