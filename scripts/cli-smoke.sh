#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'cli smoke: %s\n' "$1" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

expect_output_contains() {
  local output="$1"
  local needle="$2"

  printf '%s\n' "$output" | rg --fixed-strings --quiet -- "$needle" ||
    fail "missing expected output: $needle"
}

expect_output_omits() {
  local output="$1"
  local needle="$2"

  if printf '%s\n' "$output" | rg --fixed-strings --quiet -- "$needle"; then
    fail "unexpected output: $needle"
  fi
}

metadata="Tests/Fixtures/metadata.json"
config_file="Tests/Fixtures/credentials.env"

echo "1) list reads metadata fixture..."
list_output="$(swift run keydex list --metadata "$metadata")"
expect_output_contains "$list_output" "❌ aws/jongyun  expired  1 sources"
expect_output_contains "$list_output" "⚠️ openai/jongyun  plaintext-fallback  2 sources"

echo "2) where reads metadata fixture..."
where_output="$(swift run keydex where openai --metadata "$metadata")"
expect_output_contains "$where_output" "⚠️ openai/jongyun: plaintext-fallback"
expect_output_contains "$where_output" "[env] OPENAI_API_KEY"
expect_output_contains "$where_output" "[shell] ~/.zshrc"

echo "3) doctor reads metadata fixture..."
doctor_output="$(swift run keydex doctor --metadata "$metadata")"
expect_output_contains "$doctor_output" "⚠️ warning: openai/jongyun plaintext-fallback"
expect_output_contains "$doctor_output" "❌ error: aws/jongyun expired"
expect_output_omits "$doctor_output" "bitbucket/jongyun"
expect_output_contains "$doctor_output" "cause: credential is expired"
expect_output_contains "$doctor_output" "action: rotate or remove the credential"

echo "4) scan config reads config fixture..."
config_output="$(swift run keydex scan config --path "$config_file")"
expect_output_contains "$config_output" "▶ keydex scan config: 2 credential hints"
expect_output_contains "$config_output" "[graph] sources 1 · edges 4"

echo "5) reminders read expiry notification fixture..."
reminder_output="$(swift run keydex reminders --metadata "$metadata" --now 2026-07-01)"
expect_output_contains "$reminder_output" "❌ expired: aws/jongyun expires 2026-01-01"
expect_output_contains "$reminder_output" "notify: 2025-12-02 (30d before)"

echo "cli smoke clean"
