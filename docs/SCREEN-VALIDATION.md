# Screen Validation

Screen validation proves that the Mac app presents graph truth without visual drift,
overlap, inaccessible state, or decorative noise.

## Scope

This document applies once the SwiftUI app target exists. It defines required evidence for
M4 and release candidates.

The first local screen smoke is `scripts/app-window-smoke.sh`. It proves the app builds,
launches, and publishes the default 1080 x 680 window. It is not a replacement for the
required screenshot and accessibility evidence below.

`scripts/app-screen-evidence.sh` is the local permissioned app-screen capture path for
manual validation runs. It requires macOS Screen Recording permission and must be run
outside CI. The command writes a screenshot PNG plus a manifest into
`tmp/screen-evidence`.

Use `make app-screen-evidence` for the default inventory screen and
`make app-screen-evidence SCENARIO=empty-inventory` for the empty inventory screen.

The first source-level accessibility contract is `scripts/app-accessibility-contract.sh`.
It proves required SwiftUI surfaces expose stable accessibility labels and identifiers
before permissioned screenshot or VoiceOver evidence is attached.

## Required Screens

| Screen | Purpose |
| --- | --- |
| Empty Inventory | Show no indexed credentials and next action. |
| Inventory Table | Dense credential scan view. |
| Inspector | Selected credential relationships. |
| Doctor Panel | Repair queue grouped by severity. |
| Settings | Permissions, scan paths, ignored sources. |
| Search/Filter | Graph projection narrowing. |

## Viewport Matrix

| Viewport | Required Evidence |
| --- | --- |
| Compact Mac window | No clipped text, no overlapping panels. |
| Default Mac window | Sidebar, table, inspector balance is usable. |
| Wide desktop | Dense table remains work-focused, not hero-like. |
| Increased text size | Rows and controls remain readable. |
| Increased contrast | Risk states remain visible and labeled. |

## Visual Rules

| Rule | Evidence |
| --- | --- |
| Native Mac utility feel | Uses system controls, sidebar, toolbar, table, inspector. |
| No dashboard theater | No decorative hero cards, orbs, bokeh, or marketing layout. |
| Liquid Glass hierarchy | Material is used for sidebar, toolbar, inspector, popovers. |
| Table legibility | Repeated rows do not use heavy material effects. |
| State consistency | State chips use canonical labels. |
| Risk semantics | Warning/error color is reserved for real risk states. |

## Accessibility Rules

| Rule | Evidence |
| --- | --- |
| Color is not the only state signal | State label and icon are visible. |
| Icon-only buttons are named | Accessibility label and tooltip exist. |
| Keyboard navigation works | Sidebar, table, inspector, doctor panel reachable. |
| VoiceOver reads useful names | Credential, state, source, and action labels are clear. |
| Dynamic type is safe | Text does not overlap or truncate critical state. |

## Screenshot Scenarios

| ID | Scenario | Evidence |
| --- | --- | --- |
| UI1 | Empty state | Screenshot plus note of next action. |
| UI2 | Healthy inventory | Screenshot with registered state rows. |
| UI3 | Plaintext fallback | Screenshot with warning label and source. |
| UI4 | Missing Keychain item | Screenshot with error label and action. |
| UI5 | Duplicate credential | Screenshot with duplicate state and relationship evidence. |
| UI6 | Inspector sources | Screenshot showing stored/observed source relationships. |
| UI7 | Doctor queue | Screenshot with grouped cause/action findings. |
| UI8 | Settings permissions | Screenshot of Keychain access and scan path settings. |
| UI9 | Search/filter | Screenshot before and after graph projection filter. |
| UI10 | Compact viewport | Screenshot proving no overlap. |

## Smoke Evidence

| Evidence | Command | Meaning |
| --- | --- | --- |
| Build shell | `swift build --product KeydexApp` | The SwiftUI app compiles against graph projections. |
| Window shell | `scripts/app-window-smoke.sh` | The app launches and publishes the default window. |
| Local screen evidence | `scripts/app-screen-evidence.sh` | Captures local screenshot and manifest for manual screen review evidence in `tmp/screen-evidence` (not CI required). |
| Accessibility contract | `scripts/app-accessibility-contract.sh` | Required app surfaces expose stable labels and identifiers. |
| Doctor shell | App source uses `CredentialDoctor().inspect(graph)` | The repair queue surface is graph-derived. |
| Search shell | App source filters `CredentialProjection` rows | Search narrows graph projections without separate list truth. |
| Settings shell | App source exposes `SettingsPanel` | Permission, scan path, and unmanaged source controls are reachable. |
| Empty shell | App source exposes empty `InventoryGraph` mode | Empty inventory is an honest graph projection state. |

## Screen Review Checklist

- Does the screen show graph-derived truth?
- Does the UI avoid pretending unknown state is healthy?
- Does every unhealthy state show cause and action?
- Does text fit in compact and default windows?
- Does the visual hierarchy follow `DESIGN-SYSTEM.md`?
- Does the screen avoid primary copy-secret behavior?
- Are all state names canonical?

## Completion Rule

The first M4 shell is complete when the SwiftUI app target builds from `make guard`.
M4 itself is not complete until every required screen has screenshot evidence,
accessibility evidence, and a passing review against this document.
