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

app_sources="Apps/KeydexApp/Sources/KeydexApp"

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
  keydex.toolbar.refresh-inventory \
  keydex.toolbar.register-keychain \
  keydex.toolbar.settings \
  keydex.inspector \
  keydex.inspector.manage-keychain \
  keydex.inspector.manage-tags \
  keydex.card-detail.page \
  keydex.card-detail.back \
  keydex.card-detail.manage-keychain \
  keydex.card-detail.manage-tags \
  keydex.artwork.choose \
  keydex.artwork.reset \
  keydex.settings.close \
  keydex.settings.section-picker \
  keydex.settings.panel; do
  expect_file_contains "$app_sources" ".accessibilityIdentifier(\"$identifier\")"
done

echo "2) required reusable accessibility identifiers..."
for identifier in \
  keydex.settings.keychain-access \
  keydex.settings.request-prompt \
  keydex.settings.add-keychain-reference \
  keydex.settings.display-mode \
  keydex.settings.add-scan-path \
  keydex.settings.tag.name \
  keydex.settings.tag.assignments \
  keydex.settings.tag.color \
  keydex.settings.tag.draft-name \
  keydex.settings.tag.draft-assignments \
  keydex.settings.tag.draft-color \
  keydex.settings.add-tag \
  keydex.settings.remove-tag \
  keydex.settings.expiry-reminders-enabled \
  keydex.settings.expiry-notify-before-days \
  keydex.settings.add-ignored-source \
  keydex.settings.add-unmanaged-source; do
  expect_file_contains "$app_sources" "$identifier"
done

echo "3) required accessibility labels..."
for label in \
  "Keydex credential inventory" \
  "Credential scopes" \
  "Credential inventory table" \
  "Credential inventory cards" \
  "Credential repair queue" \
  "Credential inspector" \
  "Refresh local inventory" \
  "Credential card detail" \
  "Manage Keychain reference" \
  "Manage credential tags" \
  "Choose custom artwork" \
  "Reset custom artwork" \
  "Close settings" \
  "Register Keychain reference" \
  "Settings section" \
  "Keydex settings"; do
  expect_file_contains "$app_sources" ".accessibilityLabel(\"$label\")"
done

echo "4) required reusable accessibility labels..."
for label in \
  "Add scan path" \
  "Add keychain reference" \
  "Remove keychain reference" \
  "Remove scan path" \
  "Add tag" \
  "Remove tag" \
  "Show due reminders" \
  "Default reminder lead" \
  "Add ignored source" \
  "Remove ignored source" \
  "Add unmanaged source" \
  "Remove unmanaged source"; do
  expect_file_contains "$app_sources" "$label"
done

echo "app accessibility contract clean"
