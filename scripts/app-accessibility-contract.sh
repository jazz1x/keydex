#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app accessibility contract: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

app_source="Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift"

echo "1) required accessibility identifiers..."
for identifier in \
  keydex.shell \
  keydex.sidebar.scopes \
  keydex.inventory.table \
  keydex.inventory.empty-state \
  keydex.doctor.panel \
  keydex.toolbar.inventory-mode \
  keydex.toolbar.settings \
  keydex.inspector \
  keydex.settings.section-picker \
  keydex.settings.panel; do
  expect_file_contains "$app_source" ".accessibilityIdentifier(\"$identifier\")"
done

echo "2) required accessibility labels..."
for label in \
  "Keydex credential inventory" \
  "Credential scopes" \
  "Credential inventory table" \
  "Credential repair queue" \
  "Credential inspector" \
  "Settings section" \
  "Keydex settings"; do
  expect_file_contains "$app_source" ".accessibilityLabel(\"$label\")"
done

echo "app accessibility contract clean"
