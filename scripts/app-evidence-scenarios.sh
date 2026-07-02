#!/usr/bin/env bash

KEYDEX_EVIDENCE_SCENARIOS=(
  default-window
  card-view
  card-detail
  empty-inventory
  search-filter
  inspector
  settings
  settings-appearance
  settings-sources
  settings-paths
  settings-tags
  settings-rules
  compact-window
)

keydex_list_evidence_scenarios() {
  printf '%s\n' "${KEYDEX_EVIDENCE_SCENARIOS[@]}"
}

keydex_is_evidence_scenario() {
  local candidate="$1"
  local scenario
  local matched=1

  for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
    if [[ "$scenario" == "$candidate" ]]; then
      matched=0
      break
    fi
  done

  return "$matched"
}

keydex_supported_evidence_scenarios() {
  local scenario
  local supported=""

  for scenario in "${KEYDEX_EVIDENCE_SCENARIOS[@]}"; do
    if [[ -z "$supported" ]]; then
      supported="$scenario"
    else
      supported="$supported, $scenario"
    fi
  done

  printf '%s' "$supported"
}

keydex_evidence_inventory_mode() {
  local scenario="$1"

  keydex_is_evidence_scenario "$scenario" || return 1

  case "$scenario" in
    empty-inventory)
      printf 'empty'
      ;;
    *)
      printf 'sample'
      ;;
  esac
}

keydex_evidence_window_preset() {
  local scenario="$1"

  keydex_is_evidence_scenario "$scenario" || return 1

  case "$scenario" in
    compact-window)
      printf 'compact'
      ;;
    *)
      printf 'default'
      ;;
  esac
}
