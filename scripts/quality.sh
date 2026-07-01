#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'quality gate: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

expect_file_contains() {
  local path="$1"
  local needle="$2"

  rg --fixed-strings --quiet "$needle" "$path" ||
    fail "$path is missing expected text: $needle"
}

echo "1) CLI command inventory drift..."
help_text="$(swift run keydex --help)"
for command in list where doctor reminders scan; do
  printf '%s\n' "$help_text" | rg --quiet "^[[:space:]]+$command[[:space:]]" ||
    fail "CLI help is missing command: $command"
  expect_file_contains README.md "keydex $command"
done

echo "2) state taxonomy docs drift..."
for state in registered missing-keychain-item plaintext-fallback orphan expiring expired duplicate; do
  expect_file_contains docs/DESIGN-FOUNDATION.md "$state"
  expect_file_contains docs/PHILOSOPHY.md "$state"
done

echo "3) guardrail docs drift..."
for command in "make guard" "make quality"; do
  expect_file_contains README.md "$command"
  expect_file_contains CONTRIBUTING.md "$command"
done

echo "4) anti-goal wording drift..."
if rg --line-number --ignore-case 'Keydex is (a )?password manager' README.md docs Sources Tests Apps; then
  fail "Keydex must not be described as a password manager"
fi

echo "5) workflow drift..."
expect_file_contains .github/workflows/guard.yml "make guard"
expect_file_contains .github/workflows/guard.yml "make quality"
expect_file_contains .github/workflows/security.yml "gitleaks/gitleaks-action"
expect_file_contains .github/workflows/security.yml "aquasecurity/trivy-action"

echo "6) project contract drift..."
./scripts/project-contract.sh

echo "7) CLI smoke scenarios..."
./scripts/cli-smoke.sh

echo "8) app accessibility contract..."
./scripts/app-accessibility-contract.sh

echo "9) app design contract..."
./scripts/app-design-contract.sh

echo "10) app menubar smoke script contract..."
expect_file_contains scripts/app-menubar-smoke.sh "Keydex"
expect_file_contains scripts/app-menubar-smoke.sh "Open Keydex"
expect_file_contains scripts/app-menubar-smoke.sh "Quit Keydex"

echo "quality gate clean"
