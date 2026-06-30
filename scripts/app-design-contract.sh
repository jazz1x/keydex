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
  ".listStyle(.sidebar)" \
  "Table(rows" \
  ".searchable(" \
  "ToolbarItem" \
  "ContentUnavailableView" \
  "ScrollView {" \
  "SettingsGlassSection" \
  "SettingsStatusPill" \
  ".pickerStyle(.segmented)" \
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
  "cause: \\(row.issue.message)" \
  "action: \\(row.issue.action)" \
  ".textSelection(.enabled)"; do
  expect_file_contains "$app_source" "$needle"
done

echo "3) design system rules..."
for needle in \
  "Native first" \
  "Graph visible" \
  "Risk without theater" \
  "Liquid Glass Rules" \
  "No dashboard theater" \
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
  "shadow(" \
  "Copy secret"; do
  reject_file_contains "$app_source" "$forbidden"
done

echo "app design contract clean"
