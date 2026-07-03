#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence template: %s\n' "$1" >&2
  exit 1
}

mode=create
case "${1:-}" in
  "")
    ;;
  --force)
    mode=force
    ;;
  --refresh-pending)
    mode=refresh-pending
    ;;
  --upgrade-pending-notes)
    mode=upgrade-pending-notes
    ;;
  *)
    fail \
      "unsupported argument: $1. Expected no arguments, --force, --refresh-pending, or --upgrade-pending-notes"
    ;;
esac

[[ $# -le 1 ]] || fail "too many arguments"

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

evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

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

rewrite_manifest_value() {
  local path="$1"
  local key="$2"
  local value="$3"
  local tmp_path

  tmp_path="$(mktemp "${TMPDIR:-/tmp}/keydex-accessibility-manifest.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { prefix = key "=" }
    index($0, prefix) == 1 { print prefix value; next }
    { print }
  ' "$path" >"$tmp_path"
  mv "$tmp_path" "$path"
}

expect_pending_review_fields() {
  local manifest_path="$1"
  local key

  for key in voiceover keyboard state_not_color_only dynamic_type; do
    manifest_has_value "$manifest_path" "$key" pending ||
      fail "$manifest_path has non-pending $key; refusing to update pending evidence"
  done
}

write_notes_context() {
  local scenario="$1"
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

  printf '## Scenario Focus\n\n'
  printf -- '- Focus: %s\n' "$focus"
  printf -- '- Inventory mode: %s\n' "$inventory_mode"
  printf -- '- Window preset: %s\n' "$window_preset"
  printf -- '- Review targets:\n'

  while IFS= read -r target; do
    printf '  - %s\n' "$target"
  done < <(keydex_evidence_accessibility_targets "$scenario")

  printf '\n'
}

refresh_pending_scenario() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"

  test -f "$manifest_path" || fail "missing manifest for pending refresh: $manifest_path"
  test -s "$notes_path" || fail "missing notes for pending refresh: $notes_path"

  manifest_has_value "$manifest_path" scenario "$scenario" ||
    fail "$manifest_path has unexpected scenario for pending refresh"
  manifest_has_value "$manifest_path" notes "$notes_path" ||
    fail "$manifest_path has unexpected notes path for pending refresh"
  manifest_has_key "$manifest_path" git_sha ||
    fail "$manifest_path is missing git_sha for pending refresh"
  manifest_has_key "$manifest_path" git_dirty ||
    fail "$manifest_path is missing git_dirty for pending refresh"

  expect_pending_review_fields "$manifest_path"

  rewrite_manifest_value "$manifest_path" git_sha "$head_sha"
  rewrite_manifest_value "$manifest_path" git_dirty "$head_dirty"
  printf 'refreshed=%s\n' "$scenario"
}

upgrade_pending_notes_scenario() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"
  local first_line
  local tmp_path

  refresh_pending_scenario "$scenario" >/dev/null

  manifest_has_value "$manifest_path" notes "$notes_path" ||
    fail "$manifest_path has unexpected notes path for pending notes upgrade"
  expect_pending_review_fields "$manifest_path"

  IFS= read -r first_line <"$notes_path" ||
    fail "missing notes title for pending notes upgrade: $notes_path"
  [[ "$first_line" == "# Accessibility Evidence: $scenario" ]] ||
    fail "$notes_path has unexpected notes title for pending notes upgrade"

  if rg --fixed-strings --quiet -- "## Scenario Focus" "$notes_path"; then
    printf 'notes-current=%s\n' "$scenario"
    return
  fi

  tmp_path="$(mktemp "${TMPDIR:-/tmp}/keydex-accessibility-notes.XXXXXX")"
  {
    printf '%s\n\n' "$first_line"
    write_notes_context "$scenario"
    awk 'NR > 1 { print }' "$notes_path"
  } >"$tmp_path"
  mv "$tmp_path" "$notes_path"

  printf 'upgraded=%s\n' "$scenario"
}

write_scenario_template() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"

  if [[ "$mode" != force ]]; then
    [[ ! -e "$manifest_path" ]] || fail "refusing to overwrite existing manifest: $manifest_path"
    [[ ! -e "$notes_path" ]] || fail "refusing to overwrite existing notes: $notes_path"
  fi

  cat >"$manifest_path" <<MANIFEST
scenario=$scenario
git_sha=$head_sha
git_dirty=$head_dirty
voiceover=pending
keyboard=pending
state_not_color_only=pending
dynamic_type=pending
notes=$notes_path
reviewed_at=<ISO-8601 timestamp>
reviewer=<name or handle>
MANIFEST

  cat >"$notes_path" <<NOTES
# Accessibility Evidence: $scenario

$(write_notes_context "$scenario")
## VoiceOver

- Result: pending
- Evidence:

## Keyboard

- Result: pending
- Evidence:

## State Not Color Only

- Result: pending
- Evidence:

## Dynamic Type

- Result: pending
- Evidence:

## Open Issues

- Pending review.
NOTES

  printf 'templated=%s\n' "$scenario"
}

mkdir -p "$evidence_dir"

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  case "$mode" in
    refresh-pending)
      refresh_pending_scenario "$scenario"
      ;;
    upgrade-pending-notes)
      upgrade_pending_notes_scenario "$scenario"
      ;;
    *)
      write_scenario_template "$scenario"
      ;;
  esac
done

case "$mode" in
  refresh-pending)
    echo "app accessibility evidence refresh clean"
    ;;
  upgrade-pending-notes)
    echo "app accessibility evidence notes upgrade clean"
    ;;
  *)
    echo "app accessibility evidence template clean"
    ;;
esac
