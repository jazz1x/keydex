#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'app design contract: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

app_source="Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift"

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

expect_any_file_contains() {
  local needle="$1"
  shift

  for path in "$@"; do
    if rg --fixed-strings --quiet -- "$needle" "$path"; then
      return 0
    fi
  done

  fail "design docs are missing expected text: $needle"
}

reject_file_contains() {
  local path="$1"
  local needle="$2"

  if rg --fixed-strings --quiet -- "$needle" "$path"; then
    fail "$path contains forbidden design pattern: $needle"
  fi
}

echo "1) native Mac utility structure..."
for needle in \
  "NavigationSplitView" \
  "MusicSidebarView" \
  "MusicSearchField" \
  "MusicSidebarSection" \
  "MusicSidebarRow" \
  "KeydexSidebarWashLayer" \
  "MusicToolbarCluster" \
  "KeydexSidebarLayout" \
  "KeydexSidebarMaterialView" \
  "Table(rows" \
  "CredentialCardGrid" \
  "CredentialInspectorPanel" \
  "InventoryBackdropView" \
  "InventoryDisplayMode" \
  "isCardLibrarySurface" \
  "KeydexRailFooter" \
  "KeydexCardGridLayout" \
  "KeydexRailLayout" \
  "KeydexCardArtworkLayout" \
  "footerTopPadding" \
  "footerBottomPadding" \
  "sidebarMilkyWashLight = Color(red: 0.98" \
  "sidebarMilkyWashDark = Color.white.opacity(0.08)" \
  ".scrollContentBackground(.hidden)" \
  "ZStack(alignment: .topLeading)" \
  "stateChipFillAlpha" \
  "posterSymbolAlpha" \
  "TextField(\"Search\"" \
  "ToolbarItem" \
  "ContentUnavailableView" \
  "ScrollView {" \
  "SettingsGlassSection" \
  "SettingsStatusPill" \
  "SettingsDisplayModeRow" \
  ".pickerStyle(.segmented)" \
  ".keydexGlassButton(" \
  ".keydexSidebarGlass()" \
  ".keydexSidebarSearchRow()" \
  ".keydexControlGlassPanel(" \
  ".keydexContentPanel(" \
  ".keydexFloatingGlassPanel(" \
  ".buttonStyle(.glass" \
  ".buttonStyle(.glassProminent" \
  ".glassEffect(.regular" \
  ".backgroundExtensionEffect()" \
  "NSVisualEffectView" \
  "view.material = .sidebar" \
  ".background(.regularMaterial" \
  ".background(.ultraThinMaterial)" \
  ".background(.thinMaterial" \
  ".help("; do
  expect_file_contains "$app_source" "$needle"
done

echo "2) graph and repair surfaces..."
for needle in \
  "CredentialDoctor().inspect(graph)" \
  "CredentialProjection" \
  "canonicalStateLabel" \
  "stateTint(for:" \
  "doctorSeverityTint" \
  "primaryIssue.issue.action" \
  "Cause: \\(issue.message). Action: \\(issue.action)." \
  ".textSelection(.enabled)"; do
  expect_file_contains "$app_source" "$needle"
done

echo "3) design system rules..."
for needle in \
  "Native first" \
  "Graph visible" \
  "Risk without theater" \
  "Liquid Glass Rules" \
  "Sidebar search is not a nested glass card" \
  "Music's Library and Playlist tile hierarchy" \
  "Card mode uses a two-column Music-like library surface" \
  "adaptive bounded columns" \
  "no second outer card shell" \
  "single poster frame only" \
  "no repeated capsule badge strip" \
  "music-player-like repair rail" \
  "reserved footer rail" \
  "warm milky wash" \
  "native macOS sidebar visual effect" \
  "Sidebar scroll content hides its own background" \
  "Sidebar wash is layered above the native material" \
  "semantic state-color media wash" \
  "Poster glyphs stay subdued" \
  "flat semantic fills and strokes" \
  "Source metadata uses list/document symbols" \
  "does not expose graph-derived implementation language" \
  "Inventory Cards" \
  "No dashboard theater" \
  "no graph, constellation" \
  "No decorative cards inside cards"; do
  expect_any_file_contains "$needle" docs/DESIGN-SYSTEM.md docs/DESIGN-FOUNDATION.md
done

echo "4) anti-theater source guard..."
for forbidden in \
  "LinearGradient" \
  "RadialGradient" \
  "AngularGradient" \
  "MeshGradient" \
  "Canvas(" \
  "Path(" \
  "addLine(" \
  "GraphBackdropView" \
  "point.3.connected" \
  "trianglepath" \
  "graph-derived metadata" \
  "shadow(" \
  "Copy secret"; do
  reject_file_contains "$app_source" "$forbidden"
done

if awk '
  /private struct CredentialInventoryCard/ { in_card = 1 }
  /private struct CredentialArtworkPanel/ { in_card = 0 }
  in_card && /keydexContentPanel\(/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$app_source"; then
  fail "CredentialInventoryCard must not use a second outer card shell"
fi

if awk '
  /private struct CredentialInventoryCard/ { in_card = 1 }
  /private struct CredentialArtworkPanel/ { in_card = 0 }
  in_card && /(CredentialStateSummaryView|KeychainStatusBadge|SourceCountBadge)\(/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$app_source"; then
  fail "CredentialInventoryCard must not render a repeated capsule badge strip"
fi

if awk '
  /private struct CredentialArtworkPanel/ { in_artwork = 1 }
  /private struct CredentialPosterWash/ { in_artwork = 0 }
  in_artwork && /\.background\(\.(ultraThinMaterial|thinMaterial|regularMaterial)/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$app_source"; then
  fail "CredentialArtworkPanel must keep badges flat inside the single poster frame"
fi

if awk '
  /private struct DoctorPanel/ { in_doctor = 1 }
  /private func stateTint/ { in_doctor = 0 }
  in_doctor && /frame\(maxWidth: \.infinity/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$app_source"; then
  fail "DoctorPanel must use the centered music-player-like repair rail width"
fi

if awk '
  /private struct MusicSearchField/ { in_search = 1 }
  /private struct MusicSidebarSection/ { in_search = 0 }
  in_search && /\.background\(/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$app_source"; then
  fail "MusicSearchField must remain a plain row on the sidebar material"
fi

echo "app design contract clean"
