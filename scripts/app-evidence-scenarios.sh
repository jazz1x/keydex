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

keydex_evidence_settings_scroll_target() {
  local scenario="$1"

  keydex_is_evidence_scenario "$scenario" || return 1

  case "$scenario" in
    settings-rules)
      printf 'bottom'
      ;;
    *)
      printf 'top'
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

keydex_evidence_accessibility_focus() {
  local scenario="$1"

  keydex_is_evidence_scenario "$scenario" || return 1

  case "$scenario" in
    default-window)
      printf 'Default card inventory surface with sidebar scopes, card grid, and repair queue visible.'
      ;;
    card-view)
      printf 'Card browsing surface with credential cards, state names, and repair queue visible.'
      ;;
    card-detail)
      printf 'Credential detail surface opened from the aws ci card with scoped actions and sources visible.'
      ;;
    empty-inventory)
      printf 'Empty inventory surface that explains the intentional empty dataset and next action.'
      ;;
    search-filter)
      printf 'Filtered plaintext scope with github search results and clear search affordance visible.'
      ;;
    inspector)
      printf 'List and inspector surface for the hashicorp vault infra credential with findings visible.'
      ;;
    settings)
      printf 'Settings permissions modal with keychain access and runtime prompt controls visible.'
      ;;
    settings-appearance)
      printf 'Settings appearance modal with display mode and system light or dark contract visible.'
      ;;
    settings-sources)
      printf 'Settings sources modal with scan source toggles and disabled-source state visible.'
      ;;
    settings-paths)
      printf 'Settings paths modal with editable scan paths and add or remove controls visible.'
      ;;
    settings-tags)
      printf 'Settings tags modal with editable label names, assignments, color swatches, and actions visible.'
      ;;
    settings-rules)
      printf 'Settings rules modal with ignored sources, unmanaged sources, and expiry reminder defaults visible.'
      ;;
    compact-window)
      printf 'Compact window list surface at the minimum-width preset with repair queue still reachable.'
      ;;
    *)
      return 1
      ;;
  esac
}

keydex_evidence_accessibility_targets() {
  local scenario="$1"

  keydex_is_evidence_scenario "$scenario" || return 1

  case "$scenario" in
    default-window)
      printf '%s\n' \
        "Credential scopes sidebar" \
        "Credential inventory cards" \
        "Credential repair queue"
      ;;
    card-view)
      printf '%s\n' \
        "Credential Library card grid" \
        "Credential state names" \
        "Doctor repair queue"
      ;;
    card-detail)
      printf '%s\n' \
        "Credential card detail" \
        "Manage Keychain reference action" \
        "Sources list"
      ;;
    empty-inventory)
      printf '%s\n' \
        "Empty credential inventory state" \
        "No credential copy" \
        "Next-action copy"
      ;;
    search-filter)
      printf '%s\n' \
        "Search credentials field" \
        "Search results for github" \
        "Plaintext fallback state"
      ;;
    inspector)
      printf '%s\n' \
        "Credential inventory table" \
        "Credential inspector" \
        "Finding state labels"
      ;;
    settings)
      printf '%s\n' \
        "Keychain Permission section" \
        "Enable keychain access toggle" \
        "Request runtime keychain prompt toggle"
      ;;
    settings-appearance)
      printf '%s\n' \
        "Appearance section" \
        "Display mode segmented control" \
        "System light or dark copy"
      ;;
    settings-sources)
      printf '%s\n' \
        "Scan Sources section" \
        "Shell profiles toggle" \
        "Environment variables disabled state"
      ;;
    settings-paths)
      printf '%s\n' \
        "Scan Paths section" \
        "Existing path fields" \
        "Add scan path action"
      ;;
    settings-tags)
      printf '%s\n' \
        "Credential Tags section" \
        "Tag color swatches" \
        "Add and remove tag actions"
      ;;
    settings-rules)
      printf '%s\n' \
        "Ignored Sources section" \
        "Unmanaged Sources section" \
        "Expiry Reminders section" \
        "Default reminder lead control" \
        "Source add and remove actions"
      ;;
    compact-window)
      printf '%s\n' \
        "Compact window geometry" \
        "Credential inventory table" \
        "Credential repair queue"
      ;;
    *)
      return 1
      ;;
  esac
}
