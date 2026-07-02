#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'loop contract: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

import_regex() {
  local pattern="$1"

  printf '^[[:space:]]*(?:@[[:alnum:]_()".:,]+[[:space:]]+)*(?:(?:public|internal|package|private|fileprivate)[[:space:]]+)?import[[:space:]]+(?:(?:class|struct|enum|protocol|typealias|func|var)[[:space:]]+)?(%s)(\\.|[[:space:]]*$)' "$pattern"
}

expect_import_regex_match() {
  local sample="$1"
  local pattern="$2"

  printf '%s\n' "$sample" | rg --quiet "$(import_regex "$pattern")" ||
    fail "import guard did not match forbidden import sample: $sample"
}

expect_import_regex_miss() {
  local sample="$1"
  local pattern="$2"

  if printf '%s\n' "$sample" | rg --quiet "$(import_regex "$pattern")"; then
    fail "import guard matched allowed import sample: $sample"
  fi
}

reject_import() {
  local label="$1"
  local pattern="$2"
  shift 2

  if rg --line-number "$(import_regex "$pattern")" "$@"; then
    fail "$label imports a forbidden module or framework"
  fi
}

expect_text() {
  local path="$1"
  local text="$2"

  rg --fixed-strings --quiet -- "$text" "$path" ||
    fail "$path is missing expected text: $text"
}

reject_text() {
  local path="$1"
  local text="$2"

  if rg --fixed-strings --quiet -- "$text" "$path"; then
    fail "$path contains forbidden text: $text"
  fi
}

echo "0) import guard matcher..."
expect_import_regex_match "import KeydexStore" "KeydexStore"
expect_import_regex_match "import struct KeydexStore.MetadataRecord" "KeydexStore"
expect_import_regex_match "internal import KeydexStore" "KeydexStore"
expect_import_regex_match "@preconcurrency import KeydexStore" "KeydexStore"
expect_import_regex_miss "import KeydexStoreKit" "KeydexStore"

echo "1) architecture boundary imports..."
reject_import "KeydexCore" "SwiftUI|AppKit|Security" Sources/KeydexCore
reject_import "KeydexSources" "SwiftUI|AppKit|Security" Sources/KeydexSources
reject_import "KeydexStore" "SwiftUI|AppKit|Security" Sources/KeydexStore
reject_import "KeydexKeychain" "SwiftUI|AppKit" Sources/KeydexKeychain
reject_import "keydex CLI" "SwiftUI|AppKit" Sources/keydex
reject_import "KeydexApp" "Security" Apps/KeydexApp/Sources/KeydexApp
reject_import "KeydexCore" "KeydexKeychain|KeydexSources|KeydexStore|KeydexApp" Sources/KeydexCore
reject_import "KeydexSources" "KeydexKeychain|KeydexStore|KeydexApp" Sources/KeydexSources
reject_import "KeydexStore" "KeydexKeychain|KeydexSources|KeydexApp" Sources/KeydexStore
reject_import "KeydexKeychain" "KeydexSources|KeydexStore|KeydexApp" Sources/KeydexKeychain
reject_import "KeydexApp" "KeydexKeychain|KeydexSources|KeydexStore" Apps/KeydexApp/Sources/KeydexApp

echo "2) package dependency boundaries..."
expect_text Package.swift '.target(name: "KeydexCore")'
expect_text Package.swift 'name: "KeydexKeychain"'
expect_text Package.swift 'dependencies: ["KeydexCore"]'
expect_text Package.swift '.target(name: "KeydexSources", dependencies: ["KeydexCore"])'
expect_text Package.swift '.target(name: "KeydexStore", dependencies: ["KeydexCore"])'
expect_text Package.swift 'path: "Apps/KeydexApp/Sources/KeydexApp"'

echo "3) loop documentation wiring..."
expect_text docs/LOOP-CONTRACT.md "Keydex improves through a closed loop"
expect_text docs/LOOP-CONTRACT.md "Architecture Boundaries"
expect_text docs/LOOP-CONTRACT.md "Source imports follow the package dependency direction"
expect_text docs/LOOP-CONTRACT.md "Verification Ladder"
expect_text docs/VERIFICATION.md "Loop Contract"
expect_text README.md "LOOP-CONTRACT.md"
expect_text Makefile "loop-contract"
expect_text scripts/quality.sh "scripts/loop-contract.sh"

echo "4) app presentation boundary..."
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexAppBootstrap.swift "enum KeydexAppIcon"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexAppBootstrap.swift "struct WindowPresetApplier"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexDesignSystem.swift "enum KeydexGlassTone"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexDesignSystem.swift "extension View"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "struct InventoryContentView"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "struct CredentialInspectorPanel"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "private struct CredentialInventoryCard"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexDoctorViews.swift "struct DoctorPanel"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "struct CredentialRow"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "func sampleCredentialGraph()"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "func sampleSettingsData"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexSidebarViews.swift "struct MusicSidebarView"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexSidebarViews.swift "struct MusicToolbarCluster"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "struct SettingsPanel"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "private struct SettingsGlassSection"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexArtworkStore.swift "typealias CredentialArtworkID"
reject_text Apps/KeydexApp/Sources/KeydexApp/KeydexArtworkStore.swift "CredentialRow"
expect_text docs/LOOP-CONTRACT.md "App bootstrap helpers"
expect_text docs/LOOP-CONTRACT.md "App design tokens"
expect_text docs/LOOP-CONTRACT.md "App presentation rows"
expect_text docs/LOOP-CONTRACT.md "Inventory content, cards, tables, and inspector"
expect_text docs/LOOP-CONTRACT.md "Doctor repair rail"
expect_text docs/LOOP-CONTRACT.md "Sidebar, toolbar, and rail"
expect_text docs/LOOP-CONTRACT.md "Settings panels and rows"
expect_text docs/LOOP-CONTRACT.md "App persistence helpers use their own boundary IDs"


echo "5) shell orchestration boundary..."
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "struct KeydexApp: App"
expect_text Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "struct CredentialInventoryShellView: View"
expect_text docs/LOOP-CONTRACT.md "The shell view file keeps only app entry and inventory orchestration"
for forbidden in \
  "enum KeydexAppIcon" \
  "struct WindowPresetApplier" \
  "enum KeydexGlassTone" \
  "struct CredentialRow" \
  "struct InventoryContentView" \
  "struct CredentialInspectorPanel" \
  "struct DoctorPanel" \
  "struct MusicSidebarView" \
  "struct SettingsPanel"; do
  reject_text Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "$forbidden"
done

echo "loop contract clean"
