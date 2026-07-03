#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing evidence template contract: %s\n' "$1" >&2
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

  tmp_path="$(mktemp "${TMPDIR:-/tmp}/keydex-signing-template-contract.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { prefix = key "=" }
    index($0, prefix) == 1 { print prefix value; next }
    { print }
  ' "$path" >"$tmp_path"
  mv "$tmp_path" "$path"
}

contract_root="$(mktemp -d "${TMPDIR:-/tmp}/keydex-signing-template-contract.XXXXXX")"
evidence_dir="$contract_root/evidence"
manifest_path="$evidence_dir/release-signing.manifest"
notes_path="$evidence_dir/release-signing.md"
head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"

KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR="$evidence_dir" \
  ./scripts/release-signing-evidence-template.sh --force >/dev/null

rewrite_manifest_value "$manifest_path" git_sha oldsha
rewrite_manifest_value "$manifest_path" app_path tmp/release-smoke/keydex-oldsha-Darwin-arm64/Keydex.app
rewrite_manifest_value "$manifest_path" dmg_path tmp/release-smoke/keydex-oldsha-Darwin-arm64.dmg
printf '\n- Human-entered sentinel must survive refresh.\n' >>"$notes_path"

KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR="$evidence_dir" \
  ./scripts/release-signing-evidence-template.sh --refresh-pending >/dev/null

expect_manifest_value "$manifest_path" git_sha "$head_sha"
expect_manifest_value "$manifest_path" git_dirty "$head_dirty"
expect_manifest_value "$manifest_path" app_path "tmp/release-smoke/keydex-$head_sha-Darwin-arm64/Keydex.app"
expect_manifest_value "$manifest_path" dmg_path "tmp/release-smoke/keydex-$head_sha-Darwin-arm64.dmg"
expect_file_contains "$notes_path" "Human-entered sentinel must survive refresh."

rewrite_manifest_value "$manifest_path" developer_id_identity pass

if KEYDEX_RELEASE_SIGNING_EVIDENCE_DIR="$evidence_dir" \
  ./scripts/release-signing-evidence-template.sh --refresh-pending \
  >"$contract_root/non-pending.out" 2>"$contract_root/non-pending.err"; then
  fail "non-pending signing evidence refresh unexpectedly passed"
fi

expect_file_contains "$contract_root/non-pending.err" \
  "has non-pending developer_id_identity; refusing to refresh pending signing evidence"

echo "release signing evidence template contract clean"
