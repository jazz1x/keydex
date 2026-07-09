#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'evidence status: %s\n' "$1" >&2
  exit 1
}

command -v awk >/dev/null 2>&1 || fail "missing dependency: awk"
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

last_nonempty_line() {
  awk 'NF { line = $0 } END { print line }'
}

contains_any() {
  local haystack="$1"
  shift

  local needle
  for needle in "$@"; do
    if rg --fixed-strings --quiet -- "$needle" <<<"$haystack"; then
      return 0
    fi
  done

  return 1
}

manifest_has_value() {
  local path="$1"
  local key="$2"
  local value="$3"

  rg --fixed-strings --line-regexp --quiet -- "$key=$value" "$path"
}

manifest_has_key() {
  local path="$1"
  local key="$2"

  rg --quiet "^${key}=" "$path"
}

manifest_value_is_pending_or_pass() {
  local path="$1"
  local key="$2"

  manifest_has_value "$path" "$key" pending ||
    manifest_has_value "$path" "$key" pass
}

file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path"
}

accessibility_notes_have_context() {
  local scenario="$1"
  local notes_path="$2"
  local focus
  local inventory_mode
  local window_preset
  local target

  focus="$(keydex_evidence_accessibility_focus "$scenario")" || return 1
  inventory_mode="$(keydex_evidence_inventory_mode "$scenario")" || return 1
  window_preset="$(keydex_evidence_window_preset "$scenario")" || return 1

  file_contains "$notes_path" "## Scenario Focus" || return 1
  file_contains "$notes_path" "Focus: $focus" || return 1
  file_contains "$notes_path" "Inventory mode: $inventory_mode" || return 1
  file_contains "$notes_path" "Window preset: $window_preset" || return 1
  file_contains "$notes_path" "Review targets:" || return 1

  while IFS= read -r target; do
    file_contains "$notes_path" "$target" || return 1
  done < <(keydex_evidence_accessibility_targets "$scenario")
}

accessibility_evidence_is_current_pending() {
  local evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
  local scenario
  local pending_found=false

  for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
    local manifest_path="$evidence_dir/$scenario.manifest"
    local notes_path="$evidence_dir/$scenario.md"

    test -f "$manifest_path" || return 1
    test -s "$notes_path" || return 1

    manifest_has_value "$manifest_path" scenario "$scenario" || return 1
    manifest_has_value "$manifest_path" git_sha "$head_sha" || return 1
    manifest_has_value "$manifest_path" git_dirty "$head_dirty" || return 1
    manifest_has_value "$manifest_path" notes "$notes_path" || return 1
    manifest_has_key "$manifest_path" reviewed_at || return 1
    manifest_has_key "$manifest_path" reviewer || return 1

    for key in voiceover keyboard state_not_color_only dynamic_type; do
      manifest_value_is_pending_or_pass "$manifest_path" "$key" || return 1
      if manifest_has_value "$manifest_path" "$key" pending; then
        pending_found=true
      fi
    done

    file_contains "$notes_path" "# Accessibility Evidence: $scenario" || return 1
    file_contains "$notes_path" "VoiceOver" || return 1
    file_contains "$notes_path" "Keyboard" || return 1
    file_contains "$notes_path" "State Not Color Only" || return 1
    file_contains "$notes_path" "Dynamic Type" || return 1
    file_contains "$notes_path" "Open Issues" || return 1
    accessibility_notes_have_context "$scenario" "$notes_path" || return 1
  done

  [[ "$pending_found" == true ]]
}

accessibility_pending_summary() {
  local output
  local pending_scenarios
  local pending_fields
  local next_pending_scenario
  local next_pending_fields
  local next_pending_notes

  output="$("$script_dir/app-accessibility-evidence-status.sh")" || return 1
  pending_scenarios="$(
    printf '%s\n' "$output" |
      awk -F= '$1 == "pending_scenarios" { print $2; found = 1 } END { exit(found ? 0 : 1) }'
  )" || return 1
  pending_fields="$(
    printf '%s\n' "$output" |
      awk -F= '$1 == "pending_fields" { print $2; found = 1 } END { exit(found ? 0 : 1) }'
  )" || return 1
  next_pending_scenario="$(
    printf '%s\n' "$output" |
      awk -F= '$1 == "next_pending_scenario" { print $2; found = 1 } END { exit(found ? 0 : 1) }'
  )" || return 1
  next_pending_fields="$(
    printf '%s\n' "$output" |
      awk -F= '$1 == "next_pending_fields" { print $2; found = 1 } END { exit(found ? 0 : 1) }'
  )" || return 1
  next_pending_notes="$(
    printf '%s\n' "$output" |
      awk -F= '$1 == "next_pending_notes" { print $2; found = 1 } END { exit(found ? 0 : 1) }'
  )" || return 1

  printf 'app_accessibility_manual_pending_scenarios=%s\n' "$pending_scenarios"
  printf 'app_accessibility_manual_pending_fields=%s\n' "$pending_fields"
  printf 'app_accessibility_manual_next_pending_scenario=%s\n' "$next_pending_scenario"
  printf 'app_accessibility_manual_next_pending_fields=%s\n' "$next_pending_fields"
  printf 'app_accessibility_manual_next_pending_notes=%s\n' "$next_pending_notes"
}

release_signing_evidence_is_current_pending() {
  local evidence_dir="${KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR:-tmp/release-signing-evidence}"
  local payload_dir="tmp/release-smoke/keydex-$head_sha-Darwin-arm64"
  local manifest_path="$evidence_dir/release-signing.manifest"
  local notes_path="$evidence_dir/release-signing.md"
  local pending_found=false

  test -f "$manifest_path" || return 1
  test -s "$notes_path" || return 1

  manifest_has_value "$manifest_path" git_sha "$head_sha" || return 1
  manifest_has_value "$manifest_path" git_dirty "$head_dirty" || return 1
  manifest_has_value "$manifest_path" app_path "$payload_dir/Keydex.app" || return 1
  manifest_has_value "$manifest_path" dmg_path "$payload_dir.dmg" || return 1
  manifest_has_value "$manifest_path" notes "$notes_path" || return 1
  manifest_has_key "$manifest_path" reviewed_at || return 1
  manifest_has_key "$manifest_path" reviewer || return 1

  for key in \
    developer_id_identity \
    app_codesign_verify \
    notarization \
    stapler_validate \
    signed_dmg_checksum \
    release_candidate_updated; do
    manifest_value_is_pending_or_pass "$manifest_path" "$key" || return 1
    if manifest_has_value "$manifest_path" "$key" pending; then
      pending_found=true
    fi
  done

  file_contains "$notes_path" "# Release Signing Evidence" || return 1
  file_contains "$notes_path" "Developer ID Identity" || return 1
  file_contains "$notes_path" "App Codesign Verify" || return 1
  file_contains "$notes_path" "Notarization" || return 1
  file_contains "$notes_path" "Stapler Validate" || return 1
  file_contains "$notes_path" "Signed DMG Checksum" || return 1
  file_contains "$notes_path" "Release Candidate Update" || return 1
  file_contains "$notes_path" "Open Issues" || return 1

  [[ "$pending_found" == true ]]
}

release_signing_readiness_summary() {
  local output="$1"
  local key
  local value

  for key in developer_id_identity notarytool stapler; do
    value="$(
      printf '%s\n' "$output" |
        awk -F= -v key="$key" '$1 == key { print $2; found = 1 } END { exit(found ? 0 : 1) }'
    )" || return 1
    printf 'release_signing_readiness_%s=%s\n' "$key" "$value"
  done
}

print_review_result() {
  local label="$1"
  local state="$2"
  local reason="$3"

  last_review_state="$state"
  last_review_reason="$reason"
  printf '%s=%s\n' "$label" "$state"
  if [[ -n "$reason" ]]; then
    printf '%s_reason=%s\n' "$label" "$reason"
  fi
}

run_review() {
  local label="$1"
  local pending_state="$2"
  shift 2

  local command=("$@")
  local output
  if output="$("${command[@]}" 2>&1)"; then
    print_review_result "$label" pass ""
    return 0
  fi

  local reason
  reason="$(printf '%s\n' "$output" | last_nonempty_line)"

  case "$label" in
    app_accessibility_manual)
      if accessibility_evidence_is_current_pending; then
        print_review_result "$label" "$pending_state" "$reason"
        accessibility_pending_summary
        return 0
      fi
      ;;
    release_signing_evidence)
      if release_signing_evidence_is_current_pending; then
        print_review_result "$label" "$pending_state" "$reason"
        return 0
      fi
      ;;
    release_signing_readiness)
      if contains_any \
        "$output" \
        "missing release signing prerequisites" \
        "developer_id_identity=missing" \
        "notarytool=missing" \
        "stapler=missing" \
        "missing Developer ID Application signing identity" \
        "missing Apple notarytool" \
        "missing Apple stapler"; then
        print_review_result "$label" blocked "$reason"
        release_signing_readiness_summary "$output"
        return 0
      fi
      ;;
  esac

  print_review_result "$label" needs-attention "$reason"
  return 1
}

head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"
needs_attention=0

printf 'git_sha=%s\n' "$head_sha"
printf 'git_dirty=%s\n' "$head_dirty"

run_review app_screen_evidence current ./scripts/app-screen-evidence-review.sh || needs_attention=$((needs_attention + 1))
run_review app_accessibility_manual pending ./scripts/app-accessibility-evidence-review.sh || needs_attention=$((needs_attention + 1))
run_review release_signing_readiness blocked ./scripts/release-signing-readiness.sh ||
  needs_attention=$((needs_attention + 1))
release_signing_readiness_state="$last_review_state"

if [[ "$release_signing_readiness_state" == pass ]]; then
  run_review release_signing_evidence pending ./scripts/release-signing-evidence-review.sh ||
    needs_attention=$((needs_attention + 1))
else
  print_review_result \
    release_signing_evidence \
    blocked \
    "release signing readiness is $release_signing_readiness_state; signing evidence cannot be current until readiness passes"
fi

printf 'needs_attention=%s\n' "$needs_attention"

if [[ "$needs_attention" != 0 ]]; then
  fail "$needs_attention evidence status item(s) need attention"
fi

echo "evidence status current"
