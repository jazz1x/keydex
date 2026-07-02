#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app screen evidence review: %s\n' "$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v sips >/dev/null 2>&1 || fail "missing dependency: sips"

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

image_dimension() {
  local path="$1"
  local key="$2"
  local value

  value="$(sips -g "$key" "$path" | awk -F': ' -v key="$key" '$1 ~ key { print $2 }')"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "unable to read $key from screenshot: $path"
  printf '%s' "$value"
}

window_size() {
  local path="$1"
  local window_line
  local window_pattern='width=([0-9]+) height=([0-9]+)'

  if ! window_line="$(
    rg --line-regexp --only-matching 'window=[0-9]+ x=[0-9]+ y=[0-9]+ width=[0-9]+ height=[0-9]+' "$path"
  )"; then
    fail "$path is missing exact window geometry"
  fi

  [[ "$window_line" =~ $window_pattern ]] || fail "$path has unreadable window geometry"
  printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

review_screenshot_geometry() {
  local manifest_path="$1"
  local screenshot_path="$2"
  local pixel_width
  local pixel_height
  local window_width
  local window_height

  pixel_width="$(image_dimension "$screenshot_path" pixelWidth)"
  pixel_height="$(image_dimension "$screenshot_path" pixelHeight)"
  read -r window_width window_height < <(window_size "$manifest_path")

  expect_manifest_value "$manifest_path" screenshot_pixel_width "$pixel_width"
  expect_manifest_value "$manifest_path" screenshot_pixel_height "$pixel_height"

  ((pixel_width >= window_width)) ||
    fail "$screenshot_path pixel width $pixel_width is smaller than manifest window width $window_width"
  ((pixel_height >= window_height)) ||
    fail "$screenshot_path pixel height $pixel_height is smaller than manifest window height $window_height"
}

review_scenario() {
  local scenario="$1"
  local inventory_mode="$2"
  local window_preset="$3"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local screenshot_path="$evidence_dir/$scenario.png"

  test -f "$manifest_path" || fail "missing manifest: $manifest_path"
  test -s "$screenshot_path" || fail "missing screenshot: $screenshot_path"

  expect_manifest_value "$manifest_path" scenario "$scenario"
  expect_manifest_value "$manifest_path" inventory_mode "$inventory_mode"
  expect_manifest_value "$manifest_path" window_preset "$window_preset"
  expect_manifest_value "$manifest_path" git_sha "$head_sha"
  expect_manifest_value "$manifest_path" git_dirty "$head_dirty"
  expect_manifest_key "$manifest_path" window
  expect_file_contains "$manifest_path" "width="
  expect_file_contains "$manifest_path" "height="
  expect_manifest_value "$manifest_path" screenshot "$screenshot_path"
  expect_manifest_key "$manifest_path" captured_at
  review_screenshot_geometry "$manifest_path" "$screenshot_path"

  case "$window_preset" in
    default)
      expect_file_contains "$manifest_path" "width=1080 height=680"
      ;;
    compact)
      expect_file_contains "$manifest_path" "height=620"
      ;;
  esac

  printf 'reviewed=%s\n' "$scenario"
}

evidence_dir="${KEYDEX_SCREEN_EVIDENCE_DIR:-tmp/screen-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" ||
    fail "missing inventory mode for scenario: $scenario"
  window_preset="$(keydex_evidence_window_preset "$scenario")" ||
    fail "missing window preset for scenario: $scenario"
  review_scenario "$scenario" "$inventory_mode" "$window_preset"
done

echo "app screen evidence review clean"
