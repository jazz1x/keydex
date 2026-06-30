# Screen Validation

Screen validation proves that the Mac app presents graph truth without visual drift,
overlap, inaccessible state, or decorative noise.

## Scope

This document applies once the SwiftUI app target exists. It defines required evidence for
M4 and release candidates.

The first local screen smoke is `scripts/app-window-smoke.sh`. It proves the app builds,
launches, and publishes a stable default local window. It is not a replacement for the
required screenshot and accessibility evidence below.

`scripts/app-screen-evidence.sh` is the local permissioned app-screen capture path for
manual validation runs. It requires macOS Screen Recording permission and must be run
outside CI. The command writes a screenshot PNG plus a manifest into
`tmp/screen-evidence`.

Use `scripts/app-screen-evidence.sh --list` to inspect supported local capture
scenarios. Use `make app-screen-evidence SCENARIO=<name>` to capture a specific
scenario.

After capturing all required scenarios, run `make app-screen-evidence-review`.
It verifies that each required manifest and PNG exists, points at the current Git
SHA, and records the local window dimensions used for review.

The first source-level accessibility contract is `scripts/app-accessibility-contract.sh`.
It proves required SwiftUI surfaces expose stable accessibility labels and identifiers
before permissioned screenshot or VoiceOver evidence is attached.

The first runtime accessibility smoke is `scripts/app-accessibility-smoke.sh`. It launches
the app locally, reads the macOS accessibility tree with System Events, and proves core
surface names are visible from the running app. It requires macOS accessibility scripting
permission and is not a substitute for VoiceOver review notes.

Manual accessibility evidence is reviewed with
`scripts/app-accessibility-evidence-review.sh`. It verifies local manifests and notes in
`tmp/accessibility-evidence` for the same required scenarios as screen evidence. It is
not a CI gate because VoiceOver, keyboard traversal, dynamic type, and contrast checks
must be reviewed on a permissioned Mac session.

Use `make app-accessibility-evidence-template` to create pending local evidence files for
all required scenarios. The generated manifests intentionally use `pending` values; change
them to `pass` only after reviewing the paired notes on the current Git SHA.

The first source-level HIG and Liquid Glass contract is `scripts/app-design-contract.sh`.
It proves the app keeps native Mac utility structure, graph-derived repair surfaces,
and anti-theater visual rules wired before manual design review evidence is attached.

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

| ID | Scenario | Script Scenario | Evidence |
| --- | --- | --- | --- |
| UI1 | Empty state | `empty-inventory` | Screenshot plus note of next action. |
| UI2 | Healthy inventory | `default-window` | Screenshot with registered state rows. |
| UI3 | Plaintext fallback | `default-window` | Screenshot with warning label and source. |
| UI4 | Missing Keychain item | `default-window` | Screenshot with error label and action. |
| UI5 | Duplicate credential | `default-window` | Screenshot with duplicate state and relationship evidence. |
| UI6 | Inspector sources | `inspector` | Screenshot showing stored/observed source relationships. |
| UI7 | Doctor queue | `default-window` | Screenshot with grouped cause/action findings. |
| UI8 | Settings permissions and rules | `settings`, `settings-sources`, `settings-paths`, `settings-rules` | Screenshots of Keychain access, scan sources, scan paths, ignored sources, and unmanaged sources. |
| UI9 | Search/filter | `search-filter` | Screenshot after graph projection filtering; compare with `default-window`. |
| UI10 | Compact viewport | `compact-window` | Screenshot proving no overlap. |

## Smoke Evidence

| Evidence | Command | Meaning |
| --- | --- | --- |
| Build shell | `swift build --product KeydexApp` | The SwiftUI app compiles against graph projections. |
| Window shell | `scripts/app-window-smoke.sh` | The app launches and publishes the default window. |
| Local screen evidence | `scripts/app-screen-evidence.sh --list` and `make app-screen-evidence SCENARIO=<name>` | Captures local screenshot and manifest for manual screen review evidence in `tmp/screen-evidence` (not CI required). |
| Local screen review | `make app-screen-evidence-review` | Verifies the local screenshot and manifest set for all required script scenarios. |
| Accessibility contract | `scripts/app-accessibility-contract.sh` | Required app surfaces expose stable labels and identifiers. |
| Runtime accessibility smoke | `make app-accessibility-smoke` | Running app exposes expected sidebar, table, doctor, inspector, settings, and state names through AX. |
| Accessibility evidence template | `make app-accessibility-evidence-template` | Creates pending local manifest and notes files for every required scenario. |
| Accessibility evidence review | `make app-accessibility-evidence-review` | Verifies local VoiceOver, keyboard, state-label, and dynamic type notes for required scenarios. |
| App design contract | `scripts/app-design-contract.sh` | Native Mac utility structure, graph repair surfaces, and anti-theater rules remain wired. |
| Doctor shell | App source uses `CredentialDoctor().inspect(graph)` | The repair queue surface is graph-derived. |
| Search shell | App source filters `CredentialProjection` rows | Search narrows graph projections without separate list truth. |
| Settings shell | App source exposes `SettingsPanel` | Permission, scan path, and unmanaged source controls are reachable. |

Settings evidence captures use a fixed 720 x 520 pt sheet. This prevents material-backed
Settings sections from passing review while clipped or compressed.
| Empty shell | App source exposes empty `InventoryGraph` mode | Empty inventory is an honest graph projection state. |

## Screen Review Checklist

- Does the screen show graph-derived truth?
- Does the UI avoid pretending unknown state is healthy?
- Does every unhealthy state show cause and action?
- Does text fit in compact and default windows?
- Does the visual hierarchy follow `DESIGN-SYSTEM.md`?
- Does the screen avoid primary copy-secret behavior?
- Are all state names canonical?

## Accessibility Evidence Format

For each required script scenario, create
`tmp/accessibility-evidence/<scenario>.manifest` with these fields:

- `scenario=<scenario>`
- `git_sha=<short sha>`
- `voiceover=pass`
- `keyboard=pass`
- `state_not_color_only=pass`
- `dynamic_type=pass`
- `notes=tmp/accessibility-evidence/<scenario>.md`
- `reviewed_at=<ISO-8601 timestamp>`
- `reviewer=<name or handle>`

The paired notes file must start with `# Accessibility Evidence: <scenario>` and cover
VoiceOver, Keyboard, State Not Color Only, Dynamic Type, and Open Issues.

## Completion Rule

The first M4 shell is complete when the SwiftUI app target builds from `make guard`.
M4 itself is not complete until every required screen has screenshot evidence,
accessibility evidence, and a passing review against this document.
