#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence status: %s\n' "$1" >&2
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

manifest_value() {
  local path="$1"
  local key="$2"
  local line

  line="$(rg --line-regexp --only-matching "${key}=.*" "$path" || true)"
  [[ -n "$line" ]] || return 1
  printf '%s' "${line#*=}"
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

expect_notes_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected notes text: $needle"
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

  expect_notes_contains "$notes_path" "## Scenario Focus"
  expect_notes_contains "$notes_path" "Focus: $focus"
  expect_notes_contains "$notes_path" "Inventory mode: $inventory_mode"
  expect_notes_contains "$notes_path" "Window preset: $window_preset"
  expect_notes_contains "$notes_path" "Review targets:"

  while IFS= read -r target; do
    expect_notes_contains "$notes_path" "$target"
  done < <(keydex_evidence_accessibility_targets "$scenario")
}

review_field_state() {
  local manifest_path="$1"
  local key="$2"
  local value

  value="$(manifest_value "$manifest_path" "$key")" ||
    fail "$manifest_path is missing expected manifest key: $key"

  case "$value" in
    pass | pending)
      printf '%s' "$value"
      ;;
    *)
      fail "$manifest_path has unsupported $key value: $value"
      ;;
  esac
}

evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"
scenario_count=0
pass_scenarios=0
pending_scenarios=0
pending_fields=0
next_pending_scenario=
next_pending_fields=
next_pending_notes=
next_pending_screenshot=
next_pending_review_command=

printf 'git_sha=%s\n' "$head_sha"
printf 'git_dirty=%s\n' "$head_dirty"

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  manifest_path="$evidence_dir/$scenario.manifest"
  notes_path="$evidence_dir/$scenario.md"

  test -f "$manifest_path" || fail "missing manifest: $manifest_path"
  test -s "$notes_path" || fail "missing notes: $notes_path"

  expect_manifest_value "$manifest_path" scenario "$scenario"
  expect_manifest_value "$manifest_path" git_sha "$head_sha"
  expect_manifest_value "$manifest_path" git_dirty "$head_dirty"
  expect_manifest_value "$manifest_path" notes "$notes_path"
  expect_manifest_key "$manifest_path" reviewed_at
  expect_manifest_key "$manifest_path" reviewer

  voiceover_state="$(review_field_state "$manifest_path" voiceover)"
  keyboard_state="$(review_field_state "$manifest_path" keyboard)"
  state_state="$(review_field_state "$manifest_path" state_not_color_only)"
  dynamic_type_state="$(review_field_state "$manifest_path" dynamic_type)"

  expect_notes_contains "$notes_path" "# Accessibility Evidence: $scenario"
  expect_notes_contains "$notes_path" "VoiceOver"
  expect_notes_contains "$notes_path" "Keyboard"
  expect_notes_contains "$notes_path" "State Not Color Only"
  expect_notes_contains "$notes_path" "Dynamic Type"
  expect_notes_contains "$notes_path" "Open Issues"
  expect_notes_context "$scenario" "$notes_path"

  scenario_count=$((scenario_count + 1))
  scenario_pending_fields=0
  scenario_pending_field_names=()
  for state in "$voiceover_state" "$keyboard_state" "$state_state" "$dynamic_type_state"; do
    if [[ "$state" == pending ]]; then
      scenario_pending_fields=$((scenario_pending_fields + 1))
      pending_fields=$((pending_fields + 1))
    fi
  done

  [[ "$voiceover_state" == pending ]] && scenario_pending_field_names+=("voiceover")
  [[ "$keyboard_state" == pending ]] && scenario_pending_field_names+=("keyboard")
  [[ "$state_state" == pending ]] && scenario_pending_field_names+=("state_not_color_only")
  [[ "$dynamic_type_state" == pending ]] && scenario_pending_field_names+=("dynamic_type")

  if [[ "$scenario_pending_fields" == 0 ]]; then
    pass_scenarios=$((pass_scenarios + 1))
  else
    pending_scenarios=$((pending_scenarios + 1))
    if [[ -z "$next_pending_scenario" ]]; then
      next_pending_scenario="$scenario"
      next_pending_fields="$(
        IFS=,
        printf '%s' "${scenario_pending_field_names[*]}"
      )"
      next_pending_notes="$notes_path"
      next_pending_screenshot="tmp/screen-evidence/$scenario.png"
      next_pending_review_command="open tmp/screen-evidence/$scenario.png $notes_path"
    fi
  fi

  printf 'scenario=%s voiceover=%s keyboard=%s state_not_color_only=%s dynamic_type=%s\n' \
    "$scenario" \
    "$voiceover_state" \
    "$keyboard_state" \
    "$state_state" \
    "$dynamic_type_state"
done

printf 'scenarios=%s\n' "$scenario_count"
printf 'pass_scenarios=%s\n' "$pass_scenarios"
printf 'pending_scenarios=%s\n' "$pending_scenarios"
printf 'pending_fields=%s\n' "$pending_fields"
if [[ -n "$next_pending_scenario" ]]; then
  printf 'next_pending_scenario=%s\n' "$next_pending_scenario"
  printf 'next_pending_fields=%s\n' "$next_pending_fields"
  printf 'next_pending_notes=%s\n' "$next_pending_notes"
  printf 'next_pending_screenshot=%s\n' "$next_pending_screenshot"
  printf 'next_pending_review_command=%s\n' "$next_pending_review_command"
fi
echo "app accessibility evidence status current"
