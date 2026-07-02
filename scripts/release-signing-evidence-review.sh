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

expect_file_contains "$manifest_path" "git_sha=$head_sha"
expect_file_contains "$manifest_path" "git_dirty=$head_dirty"
expect_file_contains "$manifest_path" "app_path=$app_path"
expect_file_contains "$manifest_path" "dmg_path=$dmg_path"
expect_file_contains "$manifest_path" "developer_id_identity=pass"
expect_file_contains "$manifest_path" "app_codesign_verify=pass"
expect_file_contains "$manifest_path" "notarization=pass"
expect_file_contains "$manifest_path" "stapler_validate=pass"
expect_file_contains "$manifest_path" "signed_dmg_checksum=pass"
expect_file_contains "$manifest_path" "release_candidate_updated=pass"
expect_file_contains "$manifest_path" "notes=$notes_path"
expect_file_contains "$manifest_path" "reviewed_at="
expect_file_contains "$manifest_path" "reviewer="

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
