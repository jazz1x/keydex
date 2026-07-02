#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'evidence status: %s\n' "$1" >&2
  exit 1
}

command -v awk >/dev/null 2>&1 || fail "missing dependency: awk"
command -v git >/dev/null 2>&1 || fail "missing dependency: git"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg (ripgrep)"

git_dirty_state() {
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}

last_nonempty_line() {
  awk 'NF { line = $0 } END { print line }'
}

contains_any() {
  local haystack="$1"
  shift

  local needle
  for needle in "$@"; do
    if rg --fixed-strings --quiet -- "$needle" <<<"$haystack"; then
      return 0
    fi
  done

  return 1
}

print_review_result() {
  local label="$1"
  local state="$2"
  local reason="$3"

  printf '%s=%s\n' "$label" "$state"
  if [[ -n "$reason" ]]; then
    printf '%s_reason=%s\n' "$label" "$reason"
  fi
}

run_review() {
  local label="$1"
  local pending_state="$2"
  shift 2

  local command=("$@")
  local output
  if output="$("${command[@]}" 2>&1)"; then
    print_review_result "$label" pass ""
    return 0
  fi

  local reason
  reason="$(printf '%s\n' "$output" | last_nonempty_line)"

  case "$label" in
    app_accessibility_manual)
      if contains_any "$output" \
        "voiceover=pass" \
        "keyboard=pass" \
        "state_not_color_only=pass" \
        "dynamic_type=pass"; then
        print_review_result "$label" "$pending_state" "$reason"
        return 0
      fi
      ;;
    release_signing_evidence)
      if contains_any "$output" \
        "developer_id_identity=pass" \
        "app_codesign_verify=pass" \
        "notarization=pass" \
        "stapler_validate=pass" \
        "signed_dmg_checksum=pass" \
        "release_candidate_updated=pass"; then
        print_review_result "$label" "$pending_state" "$reason"
        return 0
      fi
      ;;
    release_signing_readiness)
      if contains_any "$output" "missing Developer ID Application signing identity"; then
        print_review_result "$label" blocked "$reason"
        return 0
      fi
      ;;
  esac

  print_review_result "$label" needs-attention "$reason"
  return 1
}

head_sha="$(git rev-parse --short HEAD)"
head_dirty="$(git_dirty_state)"
needs_attention=0

printf 'git_sha=%s\n' "$head_sha"
printf 'git_dirty=%s\n' "$head_dirty"

run_review app_screen_evidence current ./scripts/app-screen-evidence-review.sh || needs_attention=$((needs_attention + 1))
run_review app_accessibility_manual pending ./scripts/app-accessibility-evidence-review.sh || needs_attention=$((needs_attention + 1))
run_review release_signing_readiness blocked ./scripts/release-signing-readiness.sh || needs_attention=$((needs_attention + 1))
run_review release_signing_evidence pending ./scripts/release-signing-evidence-review.sh || needs_attention=$((needs_attention + 1))

printf 'needs_attention=%s\n' "$needs_attention"

if [[ "$needs_attention" != 0 ]]; then
  fail "$needs_attention evidence status item(s) need attention"
fi

echo "evidence status current"
