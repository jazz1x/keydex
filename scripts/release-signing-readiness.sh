#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'release signing readiness: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"
command -v security >/dev/null 2>&1 || fail "missing dependency: security"
command -v xcrun >/dev/null 2>&1 || fail "missing dependency: xcrun"

missing_prerequisites=()

identity_output="$(security find-identity -v -p codesigning)"
if printf '%s\n' "$identity_output" | rg --fixed-strings --quiet "Developer ID Application"; then
  echo "developer_id_identity=present"
else
  echo "developer_id_identity=missing"
  missing_prerequisites+=("Developer ID Application signing identity in the local Keychain")
fi

if xcrun --find notarytool >/dev/null; then
  echo "notarytool=present"
else
  echo "notarytool=missing"
  missing_prerequisites+=("Apple notarytool")
fi

if xcrun --find stapler >/dev/null; then
  echo "stapler=present"
else
  echo "stapler=missing"
  missing_prerequisites+=("Apple stapler")
fi

if [[ "${#missing_prerequisites[@]}" != 0 ]]; then
  missing_summary=""
  for prerequisite in "${missing_prerequisites[@]}"; do
    if [[ -z "$missing_summary" ]]; then
      missing_summary="$prerequisite"
    else
      missing_summary="$missing_summary, $prerequisite"
    fi
  done
  fail "missing release signing prerequisites: $missing_summary"
fi

echo "release signing readiness clean"
