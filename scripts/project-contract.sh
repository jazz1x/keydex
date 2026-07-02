#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'project contract: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

expect_file() {
  local path="$1"

  test -f "$path" || fail "missing file: $path"
}

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet -- "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

for path in \
  docs/GOALS.md \
  docs/PRODUCT-PLAN.md \
  docs/FEATURE-SPEC.md \
  docs/CLI-INTERFACE.md \
  docs/DESIGN-SYSTEM.md \
  docs/GRAPH-WORKFLOW.md \
  docs/LOOP-CONTRACT.md \
  docs/VERIFICATION.md \
  docs/VALIDATION-SCENARIOS.md \
  docs/SCREEN-VALIDATION.md \
  docs/RELEASE-READINESS.md \
  docs/RELEASE-CANDIDATE.md \
  docs/SIGNING-NOTARIZATION.md \
  docs/TESTING-STRATEGY.md; do
  expect_file "$path"
done
expect_file .pre-commit-config.yaml
expect_file scripts/app-accessibility-smoke.sh
expect_file scripts/app-accessibility-evidence-template.sh
expect_file scripts/app-accessibility-evidence-review.sh
expect_file scripts/app-design-contract.sh
expect_file scripts/release-signing-readiness.sh
expect_file scripts/release-signing-evidence-template.sh
expect_file scripts/release-signing-evidence-review.sh
expect_file scripts/evidence-status.sh

echo "1) project goals contract..."
for goal in G1 G2 G3 G4 G5 G6 G7 G8; do
  expect_file_contains docs/GOALS.md "$goal"
done
expect_file_contains docs/GOALS.md "Keydex owns that inventory graph."
expect_file_contains README.md "GOALS.md"

echo "2) planning pack contract..."
for document in \
  PRODUCT-PLAN.md \
  FEATURE-SPEC.md \
  VALIDATION-SCENARIOS.md \
  SCREEN-VALIDATION.md \
  RELEASE-READINESS.md \
  RELEASE-CANDIDATE.md \
  SIGNING-NOTARIZATION.md \
  TESTING-STRATEGY.md; do
  expect_file_contains README.md "$document"
  expect_file_contains docs/GOALS.md "$document"
done
expect_file_contains docs/PRODUCT-PLAN.md "Total Goal"
expect_file_contains docs/FEATURE-SPEC.md "Acceptance Criteria"
expect_file_contains docs/VALIDATION-SCENARIOS.md "Functional Scenarios"
expect_file_contains docs/SCREEN-VALIDATION.md "Screenshot Scenarios"
expect_file_contains docs/RELEASE-READINESS.md "Release Candidate Checklist"
expect_file_contains docs/TESTING-STRATEGY.md "Test Pyramid"

echo "3) CLI interface contract..."
expect_file_contains README.md "CLI-INTERFACE.md"
expect_file_contains docs/CLI-INTERFACE.md "oh-my-borory"
expect_file_contains docs/CLI-INTERFACE.md "marketboro/ai-dev/oh-my-borory"
expect_file_contains docs/CLI-INTERFACE.md "NO_COLOR"
expect_file_contains docs/CLI-INTERFACE.md "◇"
expect_file_contains docs/CLI-INTERFACE.md "●"
expect_file_contains docs/CLI-INTERFACE.md "⚠"
expect_file_contains docs/CLI-INTERFACE.md "[graph]"
expect_file_contains Sources/keydex/main.swift "private enum CLIStyle"
expect_file_contains Sources/keydex/main.swift "isatty(STDOUT_FILENO)"
expect_file_contains Sources/keydex/main.swift "NO_COLOR"
expect_file_contains Sources/keydex/main.swift "color(text, .cyan)"
expect_file_contains scripts/cli-smoke.sh "◇  keydex scan config"

echo "4) design system contract..."
for token in surface.primary surface.sidebar risk.warning risk.error spacing.row radius.card; do
  expect_file_contains docs/DESIGN-SYSTEM.md "$token"
done
for surface in "Inventory Table" "Inspector" "Doctor Panel"; do
expect_file_contains docs/DESIGN-SYSTEM.md "$surface"
done
expect_file_contains README.md "DESIGN-SYSTEM.md"

echo "5) graph workflow contract..."
for edge in stored-in observed-in has-state has-finding tagged-with duplicates; do
  expect_file_contains docs/GRAPH-WORKFLOW.md "$edge"
done
expect_file_contains docs/GRAPH-WORKFLOW.md "Everything in Keydex is a graph."
expect_file_contains docs/GRAPH-WORKFLOW.md "CredentialObservation"
expect_file_contains docs/GRAPH-WORKFLOW.md "EnvironmentScanner"
expect_file_contains docs/GRAPH-WORKFLOW.md "ConfigFileScanner"
expect_file_contains docs/GRAPH-WORKFLOW.md "KeychainInventoryScanner"
expect_file_contains Sources/KeydexCore/Domain.swift "CredentialObservation"
expect_file_contains Sources/KeydexCore/InventoryGraph.swift "init(observations:"
expect_file_contains Sources/KeydexCore/InventoryGraph.swift "InventoryGraphSummary"
expect_file_contains Sources/KeydexCore/InventoryGraph.swift "CredentialProjection"
expect_file_contains Sources/KeydexCore/CredentialInventoryReconciler.swift "CredentialInventoryReconciler"
expect_file_contains Sources/keydex/main.swift "credentialProjections"
expect_file_contains Sources/keydex/main.swift "includeKeychain"
expect_file_contains Package.swift "KeydexSources"
expect_file_contains Package.swift "KeydexApp"
expect_file_contains Package.swift "KeydexKeychainTests"
expect_file_contains Sources/KeydexSources/EnvironmentScanner.swift "EnvironmentScanner"
expect_file_contains Sources/KeydexSources/ShellProfileScanner.swift "ShellProfileScanner"
expect_file_contains Sources/KeydexSources/ConfigFileScanner.swift "ConfigFileScanner"
expect_file_contains Sources/KeydexKeychain/MacOSKeychain.swift "KeychainInventoryScanner"
expect_file_contains Sources/keydex/main.swift "InventoryGraph(observations:"
expect_file_contains Sources/keydex/main.swift "ShellProfileScanner"
expect_file_contains Sources/keydex/main.swift "ConfigFileScanner"
expect_file_contains Sources/keydex/main.swift "KeychainInventoryScanner"
expect_file_contains docs/FEATURE-SPEC.md "CredentialProjection"
expect_file_contains docs/FEATURE-SPEC.md "--metadata PATH"
expect_file_contains docs/FEATURE-SPEC.md "--include-keychain"
expect_file_contains docs/FEATURE-SPEC.md "keydex scan keychain"
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "FileMetadataStore"
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "ignoredCredentials"
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "expiresAt"
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "notifyBeforeDays"
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "invalidExpiryDate"
expect_file_contains Sources/KeydexCore/Domain.swift "CredentialExpiryReminderPlanner"
expect_file_contains Sources/keydex/main.swift "struct Reminders"
expect_file_contains README.md "keydex reminders"
expect_file_contains Sources/keydex/main.swift "ignoredCredentials(metadataPath:"
expect_file_contains Package.swift "KeydexStoreTests"
expect_file_contains Apps/KeydexApp/README.md "KeydexCore"
expect_file_contains README.md "GRAPH-WORKFLOW.md"

echo "6) verification contract..."
for gate in "Project Contract" "Branch Protection" "gitleaks" "trivy"; do
  expect_file_contains docs/VERIFICATION.md "$gate"
done
expect_file_contains .pre-commit-config.yaml "keydex-guard"
expect_file_contains .pre-commit-config.yaml "keydex-quality"
expect_file_contains .pre-commit-config.yaml "gitleaks"
expect_file_contains .github/workflows/guard.yml "name: release-smoke"
expect_file_contains .github/branch-protection-main.json "\"release-smoke\""
expect_file_contains docs/VERIFICATION.md "planning pack"
expect_file_contains docs/VERIFICATION.md "Loop Contract"
expect_file_contains docs/VERIFICATION.md "app accessibility/design contracts"
expect_file_contains CONTRIBUTING.md "app accessibility/design contracts"
expect_file_contains docs/ENFORCEMENT.md "keydex-guard"
expect_file_contains docs/VERIFICATION.md "AXUIElement"
expect_file_contains docs/VERIFICATION.md "dirty state"
expect_file_contains docs/SCREEN-VALIDATION.md "AXUIElement"
expect_file_contains docs/SCREEN-VALIDATION.md "git_dirty=<clean|dirty>"
expect_file_contains docs/ENFORCEMENT.md "Evidence manifests match current SHA and dirty state"
expect_file_contains docs/VERIFICATION.md "App Build"
expect_file_contains docs/VERIFICATION.md "App Window Smoke"
expect_file_contains docs/VERIFICATION.md "App Screen Evidence Review"
expect_file_contains docs/VALIDATION-SCENARIOS.md "Build Scenarios"
expect_file_contains docs/VALIDATION-SCENARIOS.md "Philosophy Scenarios"
expect_file_contains docs/VALIDATION-SCENARIOS.md "Security Scenarios"
expect_file_contains docs/VALIDATION-SCENARIOS.md "scripts/cli-smoke.sh"
expect_file_contains docs/SCREEN-VALIDATION.md "Accessibility Rules"
expect_file_contains docs/RELEASE-READINESS.md "Release Gates"
expect_file_contains docs/RELEASE-CANDIDATE.md "Release Notes Draft"
expect_file_contains docs/RELEASE-CANDIDATE.md "Publish Blockers"
expect_file_contains docs/RELEASE-CANDIDATE.md "make app-screen-evidence-review"
expect_file_contains docs/SIGNING-NOTARIZATION.md "xcrun notarytool submit"
expect_file_contains docs/SIGNING-NOTARIZATION.md "xcrun stapler validate"
expect_file_contains docs/SIGNING-NOTARIZATION.md "Developer ID Application"
expect_file_contains Makefile "cli-smoke"
expect_file_contains scripts/quality.sh "scripts/cli-smoke.sh"
expect_file_contains scripts/cli-smoke.sh "Tests/Fixtures/metadata.json"
expect_file_contains Makefile "swift build --product KeydexApp"
expect_file_contains Package.swift "resources: [.process(\"Resources\")]"
expect_file Apps/KeydexApp/Sources/KeydexApp/Resources/KeydexAppIcon.png
expect_file Apps/KeydexApp/Sources/KeydexApp/Resources/KeydexTrayTemplate.png
expect_file_contains Makefile "app-window-smoke"
expect_file_contains Makefile "app-menubar-smoke"
expect_file_contains Makefile "app-accessibility-contract"
expect_file_contains Makefile "app-accessibility-smoke"
expect_file_contains Makefile "app-accessibility-evidence-template"
expect_file_contains Makefile "app-accessibility-evidence-review"
expect_file_contains Makefile "app-design-contract"
expect_file_contains Makefile "app-screen-evidence"
expect_file_contains Makefile "app-screen-evidence-review"
expect_file_contains Makefile "release-smoke"
expect_file_contains Makefile "release-signing-readiness"
expect_file_contains Makefile "release-signing-evidence-template"
expect_file_contains Makefile "release-signing-evidence-review"
expect_file_contains Makefile "evidence-status"
expect_file_contains Makefile "loop-contract"
expect_file_contains scripts/loop-contract.sh "architecture boundary imports"
expect_file_contains scripts/quality.sh "scripts/loop-contract.sh"
expect_file_contains scripts/app-window-smoke.sh "stable on-screen window"
expect_file_contains scripts/app-window-smoke.sh "KEYDEX_APP_WINDOW_PRESET=default"
expect_file_contains scripts/app-menubar-smoke.sh "menu bar 2"
expect_file_contains scripts/app-menubar-smoke.sh "Open Keydex"
expect_file_contains scripts/app-menubar-smoke.sh "Quit Keydex"
expect_file_contains scripts/app-accessibility-contract.sh "keydex.inventory.table"
expect_file_contains scripts/app-accessibility-contract.sh "app_sources="
expect_file_contains scripts/app-accessibility-smoke.sh "AXUIElementCreateApplication"
expect_file_contains scripts/app-accessibility-smoke.sh "maxAXReadinessAttempts"
expect_file_contains docs/SCREEN-VALIDATION.md "AX window publication is asynchronous"
expect_file_contains scripts/app-accessibility-smoke.sh "Credential inventory table"
expect_file_contains scripts/app-accessibility-smoke.sh "Settings section"
expect_file_contains scripts/app-accessibility-evidence-template.sh "git_dirty="
expect_file_contains scripts/app-accessibility-evidence-template.sh "voiceover=pending"
expect_file_contains scripts/app-accessibility-evidence-template.sh "keyboard=pending"
expect_file_contains scripts/app-accessibility-evidence-template.sh "state_not_color_only=pending"
expect_file_contains scripts/app-accessibility-evidence-template.sh "dynamic_type=pending"
expect_file_contains scripts/app-accessibility-evidence-review.sh "tmp/accessibility-evidence"
expect_file_contains scripts/app-accessibility-evidence-review.sh "git_dirty="
expect_file_contains scripts/app-accessibility-evidence-review.sh "voiceover=pass"
expect_file_contains scripts/app-accessibility-evidence-review.sh "keyboard=pass"
expect_file_contains scripts/app-accessibility-evidence-review.sh "dynamic_type=pass"
expect_file_contains scripts/app-design-contract.sh "NavigationSplitView"
expect_file_contains scripts/app-design-contract.sh "No dashboard theater"
expect_file_contains scripts/app-design-contract.sh "LinearGradient"
expect_file_contains scripts/app-design-contract.sh "app_sources="
expect_file Apps/KeydexApp/Sources/KeydexApp/KeydexAppBootstrap.swift
expect_file Apps/KeydexApp/Sources/KeydexApp/KeydexDesignSystem.swift
expect_file Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift
expect_file Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift
expect_file Apps/KeydexApp/Sources/KeydexApp/KeydexSidebarViews.swift
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexAppBootstrap.swift "enum KeydexAppIcon"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexAppBootstrap.swift "struct WindowPresetApplier"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexDesignSystem.swift "enum KeydexGlassTone"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexDesignSystem.swift "extension View"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "struct InventoryContentView"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "struct CredentialInspectorPanel"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexInventoryViews.swift "private struct CredentialInventoryCard"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "struct CredentialRow"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "func sampleCredentialGraph()"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexPresentationModel.swift "func sampleSettingsData"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexDoctorViews.swift "struct DoctorPanel"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexDoctorViews.swift "keydex.doctor.panel"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSidebarViews.swift "struct MusicSidebarView"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSidebarViews.swift "struct MusicToolbarCluster"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "struct SettingsPanel"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "private struct SettingsGlassSection"
expect_file_contains scripts/app-design-contract.sh "inventory_source="
expect_file_contains scripts/app-design-contract.sh "sidebar_source="
expect_file_contains scripts/app-design-contract.sh "doctor_source="
expect_file_contains scripts/app-screen-evidence.sh "tmp/screen-evidence"
expect_file_contains scripts/app-screen-evidence.sh "screencapture"
expect_file_contains scripts/app-screen-evidence.sh "--list"
for scenario in \
  default-window \
  card-view \
  card-detail \
  empty-inventory \
  search-filter \
  inspector \
  settings \
  settings-appearance \
  settings-sources \
  settings-paths \
  settings-tags \
  settings-rules \
  compact-window; do
  expect_file_contains scripts/app-screen-evidence.sh "$scenario"
  expect_file_contains docs/SCREEN-VALIDATION.md "$scenario"
  expect_file_contains scripts/app-accessibility-evidence-template.sh "$scenario"
  expect_file_contains scripts/app-accessibility-evidence-review.sh "$scenario"
done
expect_file_contains scripts/app-screen-evidence.sh "empty-inventory"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_INVENTORY_MODE"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_SCREEN_SCENARIO"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_WINDOW_PRESET"
expect_file_contains scripts/app-screen-evidence-review.sh "tmp/screen-evidence"
expect_file_contains scripts/app-screen-evidence-review.sh "git rev-parse --short HEAD"
expect_file_contains scripts/app-screen-evidence-review.sh "git_dirty="
expect_file_contains scripts/app-screen-evidence-review.sh "width=1080 height=680"
expect_file_contains docs/SCREEN-VALIDATION.md "make app-screen-evidence-review"
expect_file_contains docs/SCREEN-VALIDATION.md "1080 x 680 pt"
expect_file_contains scripts/release-smoke.sh "tmp/release-smoke"
expect_file_contains scripts/release-smoke.sh "shasum -a 256"
expect_file_contains scripts/release-smoke.sh "codesign"
expect_file_contains scripts/release-smoke.sh "plutil -lint"
expect_file_contains scripts/release-smoke.sh "Info.plist"
expect_file_contains scripts/release-smoke.sh "app_bundle=Keydex.app"
expect_file_contains scripts/release-smoke.sh "app_codesign=ad-hoc"
expect_file_contains scripts/release-smoke.sh "codesign --force --deep --sign -"
expect_file_contains scripts/release-smoke.sh "codesign --verify --deep --strict"
expect_file_contains scripts/release-smoke.sh "Keydex.app/Contents/MacOS/KeydexApp"
expect_file_contains scripts/release-smoke.sh "hdiutil create"
expect_file_contains scripts/release-smoke.sh "hdiutil verify"
expect_file_contains scripts/release-smoke.sh ".dmg"
expect_file_contains scripts/release-smoke.sh "dmg="
expect_file_contains scripts/release-smoke.sh "dmg_checksum="
expect_file_contains scripts/release-smoke.sh "known_limits=app bundle signed ad-hoc (unsigned identity); unsigned DMG; Developer ID signing and notarization remain future gates"
expect_file_contains scripts/release-smoke.sh "dmg_path"
expect_file_contains scripts/release-signing-readiness.sh "Developer ID Application"
expect_file_contains scripts/release-signing-readiness.sh "notarytool"
expect_file_contains scripts/release-signing-readiness.sh "stapler"
expect_file_contains scripts/release-signing-evidence-template.sh "git_dirty="
expect_file_contains scripts/release-signing-evidence-template.sh "developer_id_identity=pending"
expect_file_contains scripts/release-signing-evidence-template.sh "notarization=pending"
expect_file_contains scripts/release-signing-evidence-template.sh "stapler_validate=pending"
expect_file_contains scripts/release-signing-evidence-review.sh "git_dirty="
expect_file_contains scripts/release-signing-evidence-review.sh "developer_id_identity=pass"
expect_file_contains scripts/release-signing-evidence-review.sh "Developer ID Application"
expect_file_contains scripts/release-signing-evidence-review.sh "xcrun stapler validate"
expect_file_contains docs/RELEASE-READINESS.md "make release-smoke"
expect_file_contains docs/RELEASE-READINESS.md "make release-signing-readiness"
expect_file_contains docs/RELEASE-READINESS.md "make release-signing-evidence-template"
expect_file_contains docs/RELEASE-READINESS.md "make release-signing-evidence-review"
expect_file_contains docs/RELEASE-READINESS.md "make app-screen-evidence-review"
expect_file_contains docs/VERIFICATION.md "Evidence Status"
expect_file_contains docs/ENFORCEMENT.md "Evidence status stays explicit"
expect_file_contains README.md "make evidence-status"
expect_file_contains scripts/evidence-status.sh "app_screen_evidence"
expect_file_contains scripts/evidence-status.sh "app_accessibility_manual"
expect_file_contains scripts/evidence-status.sh "release_signing_readiness"
expect_file_contains scripts/evidence-status.sh "release_signing_evidence"
expect_file_contains scripts/evidence-status.sh "needs-attention"
expect_file_contains scripts/quality.sh "scripts/app-accessibility-contract.sh"
expect_file_contains scripts/quality.sh "scripts/app-design-contract.sh"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "CredentialDoctor().inspect(graph)"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "CredentialProjection"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "searchText"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "EditableSettingsListSection"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "SettingsGlassSection"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift 'ForEach($settings.scanSources)'
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexSettingsViews.swift "Add scan path"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexDoctorViews.swift "primaryIssue.issue.action"
expect_file_contains docs/DESIGN-SYSTEM.md "Settings outer overlay and header controls use native Liquid Glass"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "InventoryGraph(records: [])"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift ".accessibilityIdentifier(\"keydex.shell\")"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "KEYDEX_APP_INVENTORY_MODE"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "KEYDEX_APP_SCREEN_SCENARIO"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "KEYDEX_APP_WINDOW_PRESET"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift ".state(.duplicate)"
expect_file_contains Sources/KeydexCore/Doctor.swift "inspect(_ graph: InventoryGraph)"
expect_file_contains Sources/KeydexCore/Doctor.swift "credential: CredentialRef"
expect_file_contains Sources/keydex/main.swift "CredentialDoctor().inspect(graph, ignoring: ignoredCredentials)"
expect_file_contains docs/GRAPH-WORKFLOW.md "CredentialDoctor.inspect(InventoryGraph)"
expect_file_contains docs/ENFORCEMENT.md "Project Contract"
expect_file_contains README.md "VERIFICATION.md"

echo "project contract clean"
