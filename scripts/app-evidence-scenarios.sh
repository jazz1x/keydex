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

keydex_evidence_window_width_mode() {
  local preset="$1"

  case "$preset" in
    default)
      printf 'exact'
      ;;
    compact)
      printf 'minimum'
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_window_width() {
  local preset="$1"

  case "$preset" in
    default)
      printf '1080'
      ;;
    compact)
      printf '900'
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_window_height() {
  local preset="$1"

  case "$preset" in
    default)
      printf '680'
      ;;
    compact)
      printf '620'
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_window_description() {
  local preset="$1"
  local mode
  local width
  local height

  mode="$(keydex_evidence_window_width_mode "$preset")" || return 1
  width="$(keydex_evidence_window_width "$preset")" || return 1
  height="$(keydex_evidence_window_height "$preset")" || return 1

  case "$mode" in
    exact)
      printf 'width=%s height=%s' "$width" "$height"
      ;;
    minimum)
      printf 'width>=%s height=%s' "$width" "$height"
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_window_matches_size() {
  local preset="$1"
  local width="$2"
  local height="$3"
  local mode
  local expected_width
  local expected_height

  mode="$(keydex_evidence_window_width_mode "$preset")" || return 1
  expected_width="$(keydex_evidence_window_width "$preset")" || return 1
  expected_height="$(keydex_evidence_window_height "$preset")" || return 1

  [[ "$height" == "$expected_height" ]] || return 1

  case "$mode" in
    exact)
      [[ "$width" == "$expected_width" ]]
      ;;
    minimum)
      [[ "$width" -ge "$expected_width" ]]
      ;;
    *)
      return 1
      ;;
  esac
}
