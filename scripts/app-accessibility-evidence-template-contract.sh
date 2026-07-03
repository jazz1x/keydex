#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility evidence template contract: %s\n' "$1" >&2
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

expect_manifest_value() {
  local path="$1"
  local key="$2"
  local value="$3"

  rg --fixed-strings --line-regexp --quiet -- "$key=$value" "$path" ||
    fail "$path is missing expected manifest value: $key=$value"
}

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

rewrite_manifest_value() {
  local path="$1"
  local key="$2"
  local value="$3"
  local tmp_path

  tmp_path="$(mktemp "${TMPDIR:-/tmp}/keydex-accessibility-template-contract.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { prefix = key "=" }
    index($0, prefix) == 1 { print prefix value; next }
    { print }
  ' "$path" >"$tmp_path"
  mv "$tmp_path" "$path"
}

write_legacy_notes() {
  local notes_path="$1"
  local scenario="$2"

  cat >"$notes_path" <<NOTES
# Accessibility Evidence: $scenario

## VoiceOver

- Result: pending
- Evidence:
  - Legacy note sentinel must survive upgrade.

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
}

scenario=default-window
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

refresh_root="$(mktemp -d "${TMPDIR:-/tmp}/keydex-accessibility-template-contract.XXXXXX")"
refresh_dir="$refresh_root/evidence"
refresh_manifest="$refresh_dir/$scenario.manifest"
refresh_notes="$refresh_dir/$scenario.md"

KEYDEX_ACCESSIBILITY_EVIDENCE_DIR="$refresh_dir" \
  ./scripts/app-accessibility-evidence-template.sh --force >/dev/null

rewrite_manifest_value "$refresh_manifest" git_sha oldsha
printf '\n- Human-entered accessibility sentinel must survive refresh.\n' >>"$refresh_notes"

KEYDEX_ACCESSIBILITY_EVIDENCE_DIR="$refresh_dir" \
  ./scripts/app-accessibility-evidence-template.sh --refresh-pending >/dev/null

expect_manifest_value "$refresh_manifest" git_sha "$head_sha"
expect_manifest_value "$refresh_manifest" git_dirty "$head_dirty"
expect_file_contains "$refresh_notes" "Human-entered accessibility sentinel must survive refresh."

rewrite_manifest_value "$refresh_manifest" voiceover pass

if KEYDEX_ACCESSIBILITY_EVIDENCE_DIR="$refresh_dir" \
  ./scripts/app-accessibility-evidence-template.sh --refresh-pending \
  >"$refresh_root/non-pending.out" 2>"$refresh_root/non-pending.err"; then
  fail "non-pending accessibility evidence refresh unexpectedly passed"
fi

expect_file_contains "$refresh_root/non-pending.err" \
  "has non-pending voiceover; refusing to update pending evidence"

upgrade_root="$(mktemp -d "${TMPDIR:-/tmp}/keydex-accessibility-template-contract.XXXXXX")"
upgrade_dir="$upgrade_root/evidence"
upgrade_manifest="$upgrade_dir/$scenario.manifest"
upgrade_notes="$upgrade_dir/$scenario.md"

KEYDEX_ACCESSIBILITY_EVIDENCE_DIR="$upgrade_dir" \
  ./scripts/app-accessibility-evidence-template.sh --force >/dev/null
rewrite_manifest_value "$upgrade_manifest" git_sha oldsha
write_legacy_notes "$upgrade_notes" "$scenario"

KEYDEX_ACCESSIBILITY_EVIDENCE_DIR="$upgrade_dir" \
  ./scripts/app-accessibility-evidence-template.sh --upgrade-pending-notes >/dev/null

expect_manifest_value "$upgrade_manifest" git_sha "$head_sha"
expect_manifest_value "$upgrade_manifest" git_dirty "$head_dirty"
expect_file_contains "$upgrade_notes" "## Scenario Focus"
expect_file_contains "$upgrade_notes" "- Inventory mode:"
expect_file_contains "$upgrade_notes" "Legacy note sentinel must survive upgrade."

echo "app accessibility evidence template contract clean"
