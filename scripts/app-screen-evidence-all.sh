#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

capture_scenario() {
  local scenario="$1"
  local attempt

  for attempt in 1 2; do
    printf 'capturing=%s attempt=%s\n' "$scenario" "$attempt"
    if "$script_dir/app-screen-evidence.sh" "$scenario"; then
      return 0
    fi
  done

  return 1
}

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  capture_scenario "$scenario"
done

echo "app screen evidence all clean"
