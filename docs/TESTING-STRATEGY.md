# Testing Strategy

Testing keeps Keydex honest at the smallest stable boundary first, then expands toward
CLI, app, and release evidence.

## Test Pyramid

| Level | Purpose |
| --- | --- |
| Domain unit tests | Prove typed parsing, graph edges, state labels, doctor mappings. |
| Source parser tests | Prove scanner inputs become observations without secret values. |
| Store fixture tests | Prove metadata input excludes secret values and rejects invalid states. |
| CLI scenario tests | Prove commands use graph projections and stable output. |
| App build tests | Prove the SwiftUI shell compiles against graph projections. |
| App window smoke | Prove the SwiftUI shell launches a default window locally. |
| App accessibility contract | Prove required SwiftUI surfaces expose stable labels and identifiers. |
| App screen tests | Prove SwiftUI surfaces render the graph truth. |
| Release smoke tests | Prove local release artifacts build, bundle, ad-hoc sign, create DMG, run, checksum, and omit fixture metadata. |

## Required Test Axes

| Axis | Required Evidence |
| --- | --- |
| Parse don't validate | Raw text becomes typed values at boundaries. |
| Graph projection | Commands and screens read graph output. |
| Secret boundary | Values are input only; metadata and output omit them. |
| System appearance | App renders with system light and dark appearance without custom color variants. |
| State truth | Canonical state names stay stable. |
| Cause/action | Doctor issues explain repair. |
| UI fit | Screens do not overlap or truncate critical text. |
| Keychain reconciliation | Registered, missing, and orphan states are derived from metadata-Keychain relationships. |
| Expiry reminders | `expiresAt` and `notifyBeforeDays` create deterministic scheduled/due/expired reminder evidence. |

## Test Data Rules

- Use fake values only.
- Use obvious fake prefixes such as `sk-test-secret`.
- Assert fake values do not appear in observations, metadata, CLI output, screenshots, or
  release artifacts.
- Do not commit real local paths except fixture paths.

## CLI Test Targets

| Command | Minimum Test |
| --- | --- |
| `scan env` | Fixture environment produces graph summary. |
| `scan shell` | Fixture profile produces graph summary. |
| `scan config` | Fixture config file produces graph summary. |
| `scan keychain` | Keychain item references produce orphan graph summary without values. |
| `list` | Metadata fixture graph prints rows. |
| `where` | Metadata fixture graph prints source relationships. |
| `doctor` | Metadata fixture graph prints findings. |
| `reminders` | Metadata fixture prints expiry notification schedule. |
| `--include-keychain` | Metadata and Keychain references reconcile to registered/missing/orphan states. |

The first CLI smoke gate is `scripts/cli-smoke.sh`. It uses tracked fixtures in
`Tests/Fixtures` and runs through `make quality`.

## App Test Targets

| Surface | Minimum Test |
| --- | --- |
| Sidebar | Scope selection changes graph projection. |
| Sidebar search | Search narrows the current projection without introducing separate list source. |
| Table | Rows show canonical state and source counts. |
| Card/list modes | Inventory mode switch preserves filtered projection and selected rows. |
| Row grouping | Grouped library rows expose context without creating custom hierarchy visuals. |
| Inspector | Selection shows relationships. |
| Doctor panel | Findings show cause and action. |
| Settings | Scan path and permission controls render. |

The first Doctor panel shell must read `CredentialDoctor().inspect(graph)` so repair
queue rows stay graph-derived.
The first search shell must filter `CredentialProjection` rows by service, account,
state, and source label without creating a separate list source of truth.
The first settings shell must expose Keychain permission, scan source, and unmanaged
source controls without performing mutations.
The first empty inventory shell must render an empty `InventoryGraph` rather than a
separate hardcoded list.
The first accessibility contract must run in `make quality` and check stable SwiftUI
surface labels and identifiers before permissioned screenshot evidence exists.

## Completion Rule

No milestone is complete because code exists. A milestone is complete only when tests and
verification scenarios prove the behavior promised by the corresponding specification.
