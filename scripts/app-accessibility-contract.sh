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
  keydex.inventory.cards \
  keydex.inventory.empty-state \
  keydex.doctor.panel \
  keydex.toolbar.inventory-mode \
  keydex.toolbar.display-mode \
  keydex.toolbar.register-keychain \
  keydex.toolbar.settings \
  keydex.inspector \
  keydex.inspector.manage-keychain \
  keydex.settings.section-picker \
  keydex.settings.panel; do
  expect_file_contains "$app_source" ".accessibilityIdentifier(\"$identifier\")"
done

echo "2) required reusable accessibility identifiers..."
for identifier in \
  keydex.settings.keychain-access \
  keydex.settings.request-prompt \
  keydex.settings.add-keychain-reference \
  keydex.settings.display-mode \
  keydex.settings.add-scan-path \
  keydex.settings.add-ignored-source \
  keydex.settings.add-unmanaged-source; do
  expect_file_contains "$app_source" "$identifier"
done

echo "3) required accessibility labels..."
for label in \
  "Keydex credential inventory" \
  "Credential scopes" \
  "Credential inventory table" \
  "Credential inventory cards" \
  "Credential repair queue" \
  "Credential inspector" \
  "Register Keychain reference" \
  "Settings section" \
  "Keydex settings"; do
  expect_file_contains "$app_source" ".accessibilityLabel(\"$label\")"
done

echo "4) required reusable accessibility labels..."
for label in \
  "Add scan path" \
  "Add keychain reference" \
  "Remove keychain reference" \
  "Remove scan path" \
  "Add ignored source" \
  "Remove ignored source" \
  "Add unmanaged source" \
  "Remove unmanaged source"; do
  expect_file_contains "$app_source" "$label"
done

echo "app accessibility contract clean"
