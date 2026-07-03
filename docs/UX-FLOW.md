# UX Flow Contract

Keydex is a daily Mac utility, not a dashboard demo. The app must help a user move from
uncertainty to the next concrete action without making them decode implementation details.

## Primary Loop

| Step | User Question | Required Surface | Contract |
| --- | --- | --- | --- |
| Orient | What credentials are on this Mac? | Card-first inventory, grouped list, state chips, source previews | Default view favors scannable cards; list view remains available for dense repeat work. |
| Narrow | Which item or state needs attention? | Sidebar search, clear affordance, search result header | Search filters service, account, state, tag, and source without changing graph truth. |
| Inspect | Why does this credential look risky? | Card detail or inspector | Detail surfaces show state, source relationships, findings, notes, and expiry context. |
| Act | What do I do next? | Inspector/card detail actions and Doctor rail | Unhealthy states expose cause and action; repair is explicit and user initiated. |
| Configure | How do I make Keydex match my Mac? | Settings overlay | Settings exposes keychain access, scan sources, paths, tags, ignored/unmanaged sources, and closes predictably. |

## Interaction Rules

- Card mode is the first-read mode. It should feel like a Music library shelf: browse,
  select, open detail, and come back without losing place.
- Credential cards use default artwork presets, like playlist artwork defaults, so the
  poster frame reads as an item identity rather than a flat state tile.
- List mode is the work mode. It should support repeated scanning, comparison, and quick
  inspection without decorative layout overhead.
- Search is a narrowing tool, not a separate page. Clearing search must be one visible
  action away.
- Empty inventory is not a blank canvas. It must explain that no credentials are indexed
  and point to settings or registration as the next action.
- Details must answer why before how. State and sources come before action buttons.
- Detail artwork does not carry a fake selected/focus stroke. Keyboard focus belongs to
  actual controls, not decorative identity artwork.
- Card selection must not look like a blue focus ring. Mouse selection uses the
  poster's own low-alpha tint so focus remains reserved for keyboard navigation.
- Card buttons keep keyboard focus semantics, but suppress the default system focus
  effect. Keyboard focus uses a neutral Keydex poster stroke instead of a blue ring.
- Detail return navigation keeps keyboard focus visible with a neutral inline pill
  instead of reintroducing the default blue focus ring after a card click.
- Detail and inspector actions must not auto-read as focused blue controls. Global
  registration can stay prominent, but credential-scoped actions use neutral action
  buttons unless the user explicitly focuses them.
- Actions must be explicit. Managing Keychain references, tags, ignored sources, and scan
  paths must be visible user actions rather than automatic repair.
- Primary and secondary action buttons use the action-button contract so they do not read
  as disabled glass decorations.
- Settings rows keep labels on the left and controls on the right so scanning and toggling
  do not fight each other.
- Settings add/remove controls share one icon action column so repeated label
  editing does not shift; tag color swatches sit in a fixed lane so the plus and
  minus buttons keep 0 pt trailing-edge delta.
- Tag and label color management uses swatches, not text-only color menus.
- Tag chips keep color in a small swatch inside a neutral shell, so opening card detail
  does not create a blue focus-ring look around label metadata.
- Escape and an icon close affordance must dismiss settings.
- Settings scroll content keeps a 56 pt bottom reserve so the last editable row never
  sits against the rounded sheet edge while scrolling.
- While settings is open, toolbar controls behind it are visible context, not active
  controls; users should not be able to click register, settings, or display mode
  through the sheet.
- The Doctor rail is a repair queue, not a warning decoration. It must show severity,
  count, cause, action, and a Review next entry point into the first issue.
- The global Register Keychain action stays in the toolbar. The Doctor rail must not
  replace it because registration is a global command and Doctor is a contextual repair
  queue.
- Custom artwork import only ships with a persisted asset store and fallback contract.
- Artwork actions stay near credential identity in card detail and inspector surfaces.
  They must not be nested inside tag management because artwork is presentation metadata,
  not a tag.
- Custom artwork rendering uses the Shell-owned artwork root. Views must not recreate a
  default artwork store while resolving image files.
- Accessibility labels must preserve the same workflow vocabulary: inventory, search
  results, credential detail, manage Keychain reference, manage tags, settings, and repair.

## Source Anchors

| Flow Anchor | Source Evidence |
| --- | --- |
| Card/list mode | `InventoryDisplayMode`, `CredentialCardGrid`, `CredentialInventoryTable`. |
| Default artwork | `CredentialArtworkPreset`, `CredentialDefaultArtwork`, `CredentialArtworkPanel`. |
| Custom artwork | `CredentialArtworkStore`, `artworkRootURL`, `CredentialCustomArtwork`, `CredentialArtworkActionGroup`, `keydex.artwork.choose`, `keydex.artwork.reset`. |
| Search narrowing | `MusicSearchField`, `Clear search`, `MusicSearchResultHeader`. |
| Empty state | `ContentUnavailableView`. |
| Detail and return | `CredentialMusicDetailView`, `keydex.card-detail.back`. |
| Explicit actions | `keydexActionButton`, `keydex.inspector.manage-keychain`, `keydex.inspector.manage-tags`, `keydex.card-detail.manage-keychain`, `keydex.card-detail.manage-tags`. |
| Repair queue | `DoctorPanel`, `keydex.doctor.review-next`, `reviewDoctorIssue`, `Cause:`, `Action:`. |
| Settings workflow | `SettingsToggleRow`, `SettingsDisplayModeRow`, `SettingsIconActionButton`, `CredentialTagColorSwatchPicker`, `EditableSettingsListSection`, `EditableTagListSection`, `Close settings`, Escape shortcut. |

## Review Questions

- Can a first-time user tell what is registered, missing, duplicate, expired, or orphaned?
- Can a repeat user get from search to detail to action without mode confusion?
- Does every unhealthy state expose cause and action near the place where the user sees it?
- Does card mode remain scannable and list mode remain dense?
- Does settings feel like a Mac utility surface rather than a modal wall?
- Are pending manual accessibility checks still visible in evidence status?
