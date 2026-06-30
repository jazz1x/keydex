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

  rg --fixed-strings --quiet "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

for path in \
  docs/GOALS.md \
  docs/DESIGN-SYSTEM.md \
  docs/GRAPH-WORKFLOW.md \
  docs/VERIFICATION.md; do
  expect_file "$path"
done

echo "1) project goals contract..."
for goal in G1 G2 G3 G4 G5 G6 G7 G8; do
  expect_file_contains docs/GOALS.md "$goal"
done
expect_file_contains docs/GOALS.md "Keydex owns that inventory graph."
expect_file_contains README.md "GOALS.md"

echo "2) design system contract..."
for token in surface.primary surface.sidebar risk.warning risk.error spacing.row radius.card; do
  expect_file_contains docs/DESIGN-SYSTEM.md "$token"
done
for surface in "Inventory Table" "Inspector" "Doctor Panel"; do
  expect_file_contains docs/DESIGN-SYSTEM.md "$surface"
done
expect_file_contains README.md "DESIGN-SYSTEM.md"

echo "3) graph workflow contract..."
for edge in stored-in observed-in has-state has-finding tagged-with duplicates; do
  expect_file_contains docs/GRAPH-WORKFLOW.md "$edge"
done
expect_file_contains docs/GRAPH-WORKFLOW.md "Everything in Keydex is a graph."
expect_file_contains docs/GRAPH-WORKFLOW.md "CredentialObservation"
expect_file_contains docs/GRAPH-WORKFLOW.md "EnvironmentScanner"
expect_file_contains Sources/KeydexCore/Domain.swift "CredentialObservation"
expect_file_contains Sources/KeydexCore/InventoryGraph.swift "init(observations:"
expect_file_contains Sources/KeydexCore/InventoryGraph.swift "InventoryGraphSummary"
expect_file_contains Package.swift "KeydexSources"
expect_file_contains Sources/KeydexSources/EnvironmentScanner.swift "EnvironmentScanner"
expect_file_contains Sources/KeydexSources/ShellProfileScanner.swift "ShellProfileScanner"
expect_file_contains Sources/keydex/main.swift "InventoryGraph(observations:"
expect_file_contains Sources/keydex/main.swift "ShellProfileScanner"
expect_file_contains README.md "GRAPH-WORKFLOW.md"

echo "4) verification contract..."
for gate in "Project Contract" "Branch Protection" "gitleaks" "trivy"; do
  expect_file_contains docs/VERIFICATION.md "$gate"
done
expect_file_contains docs/ENFORCEMENT.md "Project Contract"
expect_file_contains README.md "VERIFICATION.md"

echo "project contract clean"
