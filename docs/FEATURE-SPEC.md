# Feature Specification

This specification defines Keydex behavior. Implementation should satisfy the closest
stable acceptance criteria here before expanding scope.

## Domain Terms

| Term | Meaning |
| --- | --- |
| Credential | A typed service and account reference. |
| Source | A place where a credential is stored or observed. |
| Observation | A typed source fact that may become graph nodes and edges. |
| Graph | The source of truth for credential, source, state, and finding relationships. |
| Finding | A doctor issue with severity, credential, state, locations, cause, and action. |
| Metadata | User-owned annotations and references that are safe to persist. |

## Canonical States

| State | Meaning | Severity |
| --- | --- | --- |
| `registered` | Metadata and secure storage agree. | none |
| `missing-keychain-item` | Metadata references a missing Keychain item. | error |
| `plaintext-fallback` | Credential resolves from plaintext shell/env/config source. | warning |
| `orphan` | Keychain item exists without Keydex metadata. | warning |
| `expiring` | Credential is valid but near rotation date. | warning |
| `expired` | Credential should no longer be considered usable. | error |
| `duplicate` | Multiple observations appear to represent the same credential. | warning |

## Graph

| Feature | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Observation ingestion | Build graph from typed `CredentialObservation` values. | Unit tests prove credential, state, and source nodes plus edges. |
| Record compatibility | Build graph from current `CredentialRecord` store shape. | Existing record tests pass until store is graph-native. |
| Edge taxonomy | Use `stored-in`, `observed-in`, and `has-state`. | Graph workflow and tests use canonical edge labels. |
| Summary projection | Count credentials, sources, states, and edges. | CLI scan prints graph-derived counts. |
| No fake defaults | Missing graph relationships remain missing. | No parser fabricates Keychain edges. |

## Source Scanning

| Source | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Environment | Parse credential-like environment variable names. | Scanner emits observations and never stores values. |
| Shell profile | Parse direct assignments and `export` assignments. | Scanner emits observations and never stores values. |
| Config file | Parse supported config fixtures. | Future scanner emits observations and never stores values. |
| Keychain | Read Keychain item references and metadata. | Scanner emits secure storage observations without secret values. |
| Ignored source | Respect user ignore metadata. | Ignored source does not produce active finding. |

## Doctor

| Feature | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Graph input | Inspect `InventoryGraph`. | `CredentialDoctor.inspect(_ graph:)` is the primary API. |
| Cause and action | Every issue explains cause and next action. | Tests assert message/action for each state. |
| Evidence | Issue includes credential, state, and locations. | Tests assert issue evidence. |
| Registered silence | Healthy credentials do not create issues. | Tests assert no issue for `registered`. |
| Severity | Error states and warning states are stable. | Tests assert severity mapping. |

## CLI

| Command | Behavior | Acceptance Criteria |
| --- | --- | --- |
| `keydex scan env` | Scan process environment and print graph summary. | Output includes credential/source/edge counts only. |
| `keydex scan shell` | Scan known shell profiles and print graph summary. | Output includes credential/source/edge counts only. |
| `keydex scan config --path PATH` | Scan supported config files. | Output follows graph summary shape and omits values. |
| `keydex scan keychain` | Scan generic password item references as orphan candidates. | Output includes reference/source/edge counts only and omits values. |
| `keydex list` | List graph-derived credentials. | Rows include service, account, state, source count. |
| `keydex where SERVICE` | Show graph-derived source relationships. | Output includes locations and state without secret values. |
| `keydex doctor` | Print graph-derived findings. | Every issue includes severity, credential, state, cause, action. |
| `--metadata PATH` | Load metadata fixture/store input. | `list`, `where`, and `doctor` share the same file-backed store path. |

The first M3 CLI boundary uses `CredentialProjection` from `InventoryGraph` so `list` and
`where` do not maintain separate credential truth.

## Store

| Feature | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Metadata persistence | Store references, tags, notes, ignore rules, expiry metadata. | Tests prove no secret value field is persisted. |
| Metadata fixture | Load safe JSON metadata records for CLI scenarios. | File store tests prove parsing and invalid states. |
| Graph reconstruction | Load metadata and observations into graph. | Store fixture creates deterministic graph. |
| Ignore rules | Mark source or credential as intentionally unmanaged. | Doctor respects ignore metadata. |
| Expiry metadata | Track rotation dates without secret values. | Doctor emits expiring/expired states. |

## Keychain

| Feature | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Item inventory | Read service/account references. | No secret value is copied into Keydex metadata. |
| Registered state | Match metadata to Keychain item. | Graph has `stored-in` edge and `registered` state. |
| Missing item | Detect stale metadata reference. | Doctor emits `missing-keychain-item`. |
| Orphan item | Detect unmanaged Keychain item. | Doctor emits `orphan`. |

## Mac App

| Surface | Behavior | Acceptance Criteria |
| --- | --- | --- |
| Sidebar | Navigate graph scopes. | All, Expiring, Plaintext, Orphans, Duplicates, Services, Tags exist. |
| Inventory table | Show dense credential rows. | Rows use canonical states and source counts. |
| Inspector | Show selected graph relationships. | Credential, sources, state, findings, notes, actions visible. |
| Doctor panel | Show repair queue. | Findings grouped by severity and include cause/action. |
| Settings | Show permissions and scan paths. | User can manage Keychain permission and scan sources. |

## Security

| Rule | Acceptance Criteria |
| --- | --- |
| Secret values are parser input only. | Tests prove observations and store fixtures omit values. |
| No secret value columns. | Forbidden-pattern scan stays green. |
| No silent fallback. | Fallback source becomes `plaintext-fallback` state. |
| No broad repair. | Mutations require explicit user action. |

## Out Of Scope

- Password manager behavior.
- Secret sync.
- Team administration.
- Browser extension.
- App Store distribution as first release path.
