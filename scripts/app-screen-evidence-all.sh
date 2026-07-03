#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/app-evidence-scenarios.sh"

for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
  printf 'capturing=%s\n' "$scenario"
  "$script_dir/app-screen-evidence.sh" "$scenario"
done

echo "app screen evidence all clean"
