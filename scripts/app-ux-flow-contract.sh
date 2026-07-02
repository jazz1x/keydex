#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app ux flow contract: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

app_sources="Apps/KeydexApp/Sources/KeydexApp"
inventory_source="$app_sources/KeydexInventoryViews.swift"
settings_source="$app_sources/KeydexSettingsViews.swift"
sidebar_source="$app_sources/KeydexSidebarViews.swift"
doctor_source="$app_sources/KeydexDoctorViews.swift"
model_source="$app_sources/KeydexPresentationModel.swift"
ux_doc="docs/UX-FLOW.md"

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

expect_app_contains() {
  local needle="$1"

  rg --fixed-strings --quiet -- "$needle" "$app_sources" ||
    fail "app sources are missing expected text: $needle"
}

echo "1) primary user loop docs..."
for needle in \
  "Orient" \
  "Narrow" \
  "Inspect" \
  "Act" \
  "Configure" \
  "Card-first inventory" \
  "Sidebar search" \
  "Card detail or inspector" \
  "Doctor rail" \
  "Settings overlay" \
  "labels on the left and controls on the right" \
  "Escape" \
  "pending manual accessibility checks"; do
  expect_file_contains "$ux_doc" "$needle"
done

echo "2) orient and narrow flow anchors..."
for needle in \
  "enum InventoryDisplayMode" \
  "case list" \
  "case cards" \
  "Switch between list and card inventory views" \
  "CredentialCardGrid" \
  "CredentialInventoryTable" \
  "MusicSearchField" \
  "Clear search" \
  "MusicSearchResultHeader" \
  "Search results for" \
  "ContentUnavailableView"; do
  expect_app_contains "$needle"
done

echo "3) inspect and action flow anchors..."
for needle in \
  "CredentialMusicDetailView" \
  "keydex.card-detail.back" \
  "keydex.card-detail.manage-keychain" \
  "keydex.card-detail.manage-tags" \
  "keydex.inspector.manage-keychain" \
  "keydex.inspector.manage-tags" \
  "Manage Keychain reference" \
  "Manage credential tags" \
  "primaryIssue.issue.action" \
  "Cause: \\(issue.message). Action: \\(issue.action)."; do
  expect_app_contains "$needle"
done

echo "4) settings and dismissal flow anchors..."
for needle in \
  "SettingsToggleRow" \
  "SettingsDisplayModeRow" \
  "EditableSettingsListSection" \
  "EditableTagListSection" \
  "keydex.settings.keychain-access" \
  "keydex.settings.add-scan-path" \
  "keydex.settings.add-tag" \
  "keydex.settings.close" \
  "Close settings" \
  ".keyboardShortcut(.escape, modifiers: [])" \
  ".frame(width: 54, alignment: .trailing)"; do
  expect_app_contains "$needle"
done

echo "5) repair queue usability anchors..."
for needle in \
  "struct DoctorPanel" \
  "No repair issues are currently listed." \
  "doctorSeverityTint" \
  "issue.action" \
  "footerReserveHeight: KeydexRailLayout.footerLaneHeight"; do
  expect_app_contains "$needle"
done

if ! awk '
  /private struct SettingsToggleRow/ { in_toggle = 1 }
  /private struct SettingsEditableRow/ { in_toggle = 0 }
  in_toggle && /\.frame\(maxWidth: \.infinity, alignment: \.leading\)/ { leading = 1 }
  in_toggle && /Toggle\(title, isOn:/ { toggle = 1 }
  in_toggle && /\.labelsHidden\(\)/ { hidden = 1 }
  in_toggle && /\.frame\(width: 54, alignment: \.trailing\)/ { trailing = 1 }
  END { exit(leading && toggle && hidden && trailing ? 0 : 1) }
' "$settings_source"; then
  fail "SettingsToggleRow must keep left text and right-aligned hidden-label toggle controls"
fi

if ! awk '
  /private struct CredentialInventoryCard/ { in_card = 1 }
  /private struct CredentialArtworkPanel/ { in_card = 0 }
  in_card && /Button\(action: selectAction\)/ { button = 1 }
  in_card && /row.cardAccessibilityLabel/ { label = 1 }
  END { exit(button && label ? 0 : 1) }
' "$inventory_source"; then
  fail "Credential cards must remain selectable and carry workflow accessibility labels"
fi

if ! awk '
  /struct MusicSearchField/ { in_search = 1 }
  /struct MusicSidebarSection/ { in_search = 0 }
  in_search && /TextField\("Search"/ { field = 1 }
  in_search && /Clear search/ { clear = 1 }
  END { exit(field && clear ? 0 : 1) }
' "$sidebar_source"; then
  fail "Sidebar search must keep the search field and clear action in the same flow"
fi

expect_file_contains "$model_source" "cardDetail"
expect_file_contains "$doctor_source" "No repair issues are currently listed."

echo "app ux flow contract clean"
