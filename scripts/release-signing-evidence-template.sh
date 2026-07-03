#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing evidence template: %s\n' "$1" >&2
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
  *)
    fail "unsupported argument: $1. Expected no arguments, --force, or --refresh-pending"
    ;;
esac

[[ $# -le 1 ]] || fail "too many arguments"

command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

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

  tmp_path="$(mktemp "${TMPDIR:-/tmp}/keydex-signing-manifest.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { prefix = key "=" }
    index($0, prefix) == 1 { print prefix value; next }
    { print }
  ' "$path" >"$tmp_path"
  mv "$tmp_path" "$path"
}

expect_pending_signing_fields() {
  local key

  for key in \
    developer_id_identity \
    app_codesign_verify \
    notarization \
    stapler_validate \
    signed_dmg_checksum \
    release_candidate_updated; do
    manifest_has_value "$manifest_path" "$key" pending ||
      fail "$manifest_path has non-pending $key; refusing to refresh pending signing evidence"
  done
}

refresh_pending_manifest() {
  test -f "$manifest_path" || fail "missing manifest for pending refresh: $manifest_path"
  test -s "$notes_path" || fail "missing notes for pending refresh: $notes_path"

  manifest_has_value "$manifest_path" notes "$notes_path" ||
    fail "$manifest_path has unexpected notes path for pending refresh"
  manifest_has_key "$manifest_path" git_sha ||
    fail "$manifest_path is missing git_sha for pending refresh"
  manifest_has_key "$manifest_path" git_dirty ||
    fail "$manifest_path is missing git_dirty for pending refresh"
  manifest_has_key "$manifest_path" app_path ||
    fail "$manifest_path is missing app_path for pending refresh"
  manifest_has_key "$manifest_path" dmg_path ||
    fail "$manifest_path is missing dmg_path for pending refresh"

  expect_pending_signing_fields

  rewrite_manifest_value "$manifest_path" git_sha "$head_sha"
  rewrite_manifest_value "$manifest_path" git_dirty "$head_dirty"
  rewrite_manifest_value "$manifest_path" app_path "$payload_dir/Keydex.app"
  rewrite_manifest_value "$manifest_path" dmg_path "$payload_dir.dmg"
  echo "release signing evidence refresh clean"
}

if [[ "$mode" == "refresh-pending" ]]; then
  refresh_pending_manifest
  exit 0
fi

if [[ "$mode" != "force" ]]; then
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
