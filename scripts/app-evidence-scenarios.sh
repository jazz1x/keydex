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
  case "$1" in
    empty-inventory)
      printf 'empty'
      ;;
    default-window | card-view | card-detail | search-filter | inspector | settings | settings-appearance | settings-sources | settings-paths | settings-tags | settings-rules | compact-window)
      printf 'sample'
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_window_preset() {
  case "$1" in
    compact-window)
      printf 'compact'
      ;;
    default-window | card-view | card-detail | empty-inventory | search-filter | inspector | settings | settings-appearance | settings-sources | settings-paths | settings-tags | settings-rules)
      printf 'default'
      ;;
    *)
      return 1
      ;;
  esac
}
