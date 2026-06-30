#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing readiness: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v security >/dev/null 2>&1 || fail "missing dependency: security"
command -v xcrun >/dev/null 2>&1 || fail "missing dependency: xcrun"

identity_output="$(security find-identity -v -p codesigning)"
printf '%s\n' "$identity_output" | rg --fixed-strings --quiet "Developer ID Application" ||
  fail "missing Developer ID Application signing identity in the local Keychain"

xcrun --find notarytool >/dev/null ||
  fail "missing Apple notarytool"

xcrun --find stapler >/dev/null ||
  fail "missing Apple stapler"

echo "developer_id_identity=present"
echo "notarytool=present"
echo "stapler=present"
echo "release signing readiness clean"
