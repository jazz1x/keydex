#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence template: %s\n' "$1" >&2
  exit 1
}

force=false
if [[ "${1:-}" == "--force" ]]; then
  force=true
elif [[ $# -gt 0 ]]; then
  fail "unsupported argument: $1. Expected no arguments or --force"
fi

command -v git >/dev/null 2>&1 || fail "missing dependency: git"

evidence_dir="${KEYDEX_ACCESSIBILITY_EVIDENCE_DIR:-tmp/accessibility-evidence}"
head_sha="$(git rev-parse --short HEAD)"

write_scenario_template() {
  local scenario="$1"
  local manifest_path="$evidence_dir/$scenario.manifest"
  local notes_path="$evidence_dir/$scenario.md"

  if [[ "$force" != true ]]; then
    [[ ! -e "$manifest_path" ]] || fail "refusing to overwrite existing manifest: $manifest_path"
    [[ ! -e "$notes_path" ]] || fail "refusing to overwrite existing notes: $notes_path"
  fi

  cat >"$manifest_path" <<MANIFEST
scenario=$scenario
git_sha=$head_sha
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

write_scenario_template default-window
write_scenario_template card-view
write_scenario_template card-detail
write_scenario_template empty-inventory
write_scenario_template search-filter
write_scenario_template inspector
write_scenario_template settings
write_scenario_template settings-appearance
write_scenario_template settings-sources
write_scenario_template settings-paths
write_scenario_template settings-tags
write_scenario_template settings-rules
write_scenario_template compact-window

echo "app accessibility evidence template clean"
