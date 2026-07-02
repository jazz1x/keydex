#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing evidence template: %s\n' "$1" >&2
  exit 1
}

force=false
if [[ "${1:-}" == "--force" ]]; then
  force=true
elif [[ $# -gt 0 ]]; then
  fail "unsupported argument: $1. Expected no arguments or --force"
fi

command -v git >/dev/null 2>&1 || fail "missing dependency: git"

git_dirty_state() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}

evidence_dir="${KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR:-tmp/release-signing-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"
payload_dir="tmp/release-smoke/keydex-$head_sha-Darwin-arm64"
manifest_path="$evidence_dir/release-signing.manifest"
notes_path="$evidence_dir/release-signing.md"

if [[ "$force" != true ]]; then
  [[ ! -e "$manifest_path" ]] || fail "refusing to overwrite existing manifest: $manifest_path"
  [[ ! -e "$notes_path" ]] || fail "refusing to overwrite existing notes: $notes_path"
fi

mkdir -p "$evidence_dir"

cat >"$manifest_path" <<MANIFEST
git_sha=$head_sha
git_dirty=$head_dirty
app_path=$payload_dir/Keydex.app
dmg_path=$payload_dir.dmg
developer_id_identity=pending
app_codesign_verify=pending
notarization=pending
stapler_validate=pending
signed_dmg_checksum=pending
release_candidate_updated=pending
notes=$notes_path
reviewed_at=<ISO-8601 timestamp>
reviewer=<name or handle>
MANIFEST

cat >"$notes_path" <<NOTES
# Release Signing Evidence

## Developer ID Identity

- Result: pending
- Evidence:

## App Codesign Verify

- Result: pending
- Evidence:

## Notarization

- Result: pending
- Evidence:

## Stapler Validate

- Result: pending
- Evidence:

## Signed DMG Checksum

- Result: pending
- Evidence:

## Release Candidate Update

- Result: pending
- Evidence:

## Open Issues

- Pending review.
NOTES

printf 'manifest=%s\n' "$manifest_path"
printf 'notes=%s\n' "$notes_path"
echo "release signing evidence template clean"
