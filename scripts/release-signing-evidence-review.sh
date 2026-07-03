#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing evidence review: %s\n' "$1" >&2
  exit 1
}

command -v codesign >/dev/null 2>&1 || fail "missing dependency: codesign"
command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v shasum >/dev/null 2>&1 || fail "missing dependency: shasum"
command -v xcrun >/dev/null 2>&1 || fail "missing dependency: xcrun"

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

manifest_value() {
  local path="$1"
  local key="$2"
  local line

  line="$(rg --line-regexp --only-matching "${key}=.*" "$path" || true)"
  [[ -n "$line" ]] || return 1
  printf '%s' "${line#*=}"
}

expect_manifest_review_value() {
  local path="$1"
  local key="$2"
  local template_value="$3"
  local value

  value="$(manifest_value "$path" "$key")" ||
    fail "$path is missing expected manifest key: $key"
  [[ -n "$value" ]] ||
    fail "$path has empty review audit value: $key"
  [[ "$value" != "$template_value" ]] ||
    fail "$path still has template review audit value: $key=$template_value"
}

evidence_dir="${KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR:-tmp/release-signing-evidence}"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"
payload_dir="tmp/release-smoke/keydex-$head_sha-Darwin-arm64"
manifest_path="$evidence_dir/release-signing.manifest"
notes_path="$evidence_dir/release-signing.md"
app_path="$payload_dir/Keydex.app"
dmg_path="$payload_dir.dmg"

test -f "$manifest_path" || fail "missing manifest: $manifest_path"
test -s "$notes_path" || fail "missing notes: $notes_path"
test -d "$app_path" || fail "missing app bundle: $app_path"
test -s "$dmg_path" || fail "missing DMG: $dmg_path"

expect_manifest_value "$manifest_path" git_sha "$head_sha"
expect_manifest_value "$manifest_path" git_dirty "$head_dirty"
expect_manifest_value "$manifest_path" app_path "$app_path"
expect_manifest_value "$manifest_path" dmg_path "$dmg_path"
expect_manifest_value "$manifest_path" developer_id_identity pass
expect_manifest_value "$manifest_path" app_codesign_verify pass
expect_manifest_value "$manifest_path" notarization pass
expect_manifest_value "$manifest_path" stapler_validate pass
expect_manifest_value "$manifest_path" signed_dmg_checksum pass
expect_manifest_value "$manifest_path" release_candidate_updated pass
expect_manifest_value "$manifest_path" notes "$notes_path"
expect_manifest_review_value "$manifest_path" reviewed_at "<ISO-8601 timestamp>"
expect_manifest_review_value "$manifest_path" reviewer "<name or handle>"

expect_file_contains "$notes_path" "# Release Signing Evidence"
expect_file_contains "$notes_path" "Developer ID Identity"
expect_file_contains "$notes_path" "App Codesign Verify"
expect_file_contains "$notes_path" "Notarization"
expect_file_contains "$notes_path" "Stapler Validate"
expect_file_contains "$notes_path" "Signed DMG Checksum"
expect_file_contains "$notes_path" "Release Candidate Update"
expect_file_contains "$notes_path" "Open Issues"

codesign --verify --deep --strict "$app_path" ||
  fail "Developer ID app codesign verification failed"

codesign_output="$(codesign -dv "$app_path" 2>&1)"
printf '%s\n' "$codesign_output" | rg --fixed-strings --quiet "Developer ID Application" ||
  fail "app bundle is not signed with a Developer ID Application identity"

xcrun stapler validate "$dmg_path" ||
  fail "stapled notarization ticket validation failed"

shasum -a 256 "$dmg_path" >/dev/null ||
  fail "signed DMG checksum failed"

echo "release signing evidence review clean"
