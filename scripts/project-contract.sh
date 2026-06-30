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
  docs/DESIGN-SYSTEM.md \
  docs/GRAPH-WORKFLOW.md \
  docs/VERIFICATION.md \
  docs/VALIDATION-SCENARIOS.md \
  docs/SCREEN-VALIDATION.md \
  docs/RELEASE-READINESS.md \
  docs/RELEASE-CANDIDATE.md \
  docs/SIGNING-NOTARIZATION.md \
  docs/TESTING-STRATEGY.md; do
  expect_file "$path"
done

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

echo "3) design system contract..."
for token in surface.primary surface.sidebar risk.warning risk.error spacing.row radius.card; do
  expect_file_contains docs/DESIGN-SYSTEM.md "$token"
done
for surface in "Inventory Table" "Inspector" "Doctor Panel"; do
expect_file_contains docs/DESIGN-SYSTEM.md "$surface"
done
expect_file_contains README.md "DESIGN-SYSTEM.md"

echo "4) graph workflow contract..."
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
expect_file_contains Sources/KeydexStore/FileMetadataStore.swift "invalidExpiryDate"
expect_file_contains Sources/keydex/main.swift "ignoredCredentials(metadataPath:"
expect_file_contains Package.swift "KeydexStoreTests"
expect_file_contains Apps/KeydexApp/README.md "KeydexCore"
expect_file_contains README.md "GRAPH-WORKFLOW.md"

echo "5) verification contract..."
for gate in "Project Contract" "Branch Protection" "gitleaks" "trivy"; do
  expect_file_contains docs/VERIFICATION.md "$gate"
done
expect_file_contains .github/workflows/guard.yml "name: release-smoke"
expect_file_contains .github/branch-protection-main.json "\"release-smoke\""
expect_file_contains docs/VERIFICATION.md "planning pack"
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
expect_file_contains Makefile "app-window-smoke"
expect_file_contains Makefile "app-accessibility-contract"
expect_file_contains Makefile "app-screen-evidence"
expect_file_contains Makefile "app-screen-evidence-review"
expect_file_contains Makefile "release-smoke"
expect_file_contains scripts/app-window-smoke.sh "stable on-screen window"
expect_file_contains scripts/app-window-smoke.sh "KEYDEX_APP_WINDOW_PRESET=default"
expect_file_contains scripts/app-accessibility-contract.sh "keydex.inventory.table"
expect_file_contains scripts/app-screen-evidence.sh "tmp/screen-evidence"
expect_file_contains scripts/app-screen-evidence.sh "screencapture"
expect_file_contains scripts/app-screen-evidence.sh "--list"
for scenario in \
  default-window \
  empty-inventory \
  search-filter \
  inspector \
  settings \
  settings-sources \
  settings-paths \
  settings-rules \
  compact-window; do
  expect_file_contains scripts/app-screen-evidence.sh "$scenario"
  expect_file_contains docs/SCREEN-VALIDATION.md "$scenario"
done
expect_file_contains scripts/app-screen-evidence.sh "empty-inventory"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_INVENTORY_MODE"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_SCREEN_SCENARIO"
expect_file_contains scripts/app-screen-evidence.sh "KEYDEX_APP_WINDOW_PRESET"
expect_file_contains scripts/app-screen-evidence-review.sh "tmp/screen-evidence"
expect_file_contains scripts/app-screen-evidence-review.sh "git rev-parse --short HEAD"
expect_file_contains docs/SCREEN-VALIDATION.md "make app-screen-evidence-review"
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
expect_file_contains docs/RELEASE-READINESS.md "make release-smoke"
expect_file_contains docs/RELEASE-READINESS.md "make app-screen-evidence-review"
expect_file_contains scripts/quality.sh "scripts/app-accessibility-contract.sh"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "CredentialDoctor().inspect(graph)"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "CredentialProjection"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "searchText"
expect_file_contains Apps/KeydexApp/Sources/KeydexApp/KeydexApp.swift "SettingsPanel"
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
