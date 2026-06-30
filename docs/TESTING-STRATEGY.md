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
| App screen tests | Prove SwiftUI surfaces render the graph truth. |
| Release smoke tests | Prove packaged artifacts run. |

## Required Test Themes

| Theme | Required Evidence |
| --- | --- |
| Parse don't validate | Raw text becomes typed values at boundaries. |
| Graph projection | Commands and screens read graph output. |
| Secret boundary | Values are input only; metadata and output omit them. |
| State truth | Canonical state names stay stable. |
| Cause/action | Doctor issues explain repair. |
| UI fit | Screens do not overlap or truncate critical text. |

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

The first CLI smoke gate is `scripts/cli-smoke.sh`. It uses tracked fixtures in
`Tests/Fixtures` and runs through `make quality`.

## App Test Targets

| Surface | Minimum Test |
| --- | --- |
| Sidebar | Scope selection changes graph projection. |
| Table | Rows show canonical state and source counts. |
| Inspector | Selection shows relationships. |
| Doctor panel | Findings show cause and action. |
| Settings | Scan path and permission controls render. |

## Completion Rule

No milestone is complete because code exists. A milestone is complete only when tests and
verification scenarios prove the behavior promised by the corresponding specification.
