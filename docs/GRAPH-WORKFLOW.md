# Graph Workflow

Everything in Keydex is a graph.

The graph is not decorative architecture. It is the smallest structure that keeps
credential inventory honest across CLI, UI, doctor, and future automation.

## Graph Model

| Node | Meaning |
| --- | --- |
| Credential | A parsed service and account reference. |
| Source | A place where the credential was observed or stored. |
| State | A canonical health state. |
| Finding | A doctor issue with cause and action. |
| Tag | A user-owned grouping label. |

| Edge | Meaning |
| --- | --- |
| `stored-in` | Credential is intentionally stored in a secret store. |
| `observed-in` | Credential was discovered in a source. |
| `has-state` | Credential currently resolves to a state. |
| `has-finding` | Credential has a doctor finding. |
| `tagged-with` | Credential has a user tag. |
| `duplicates` | Two credential nodes appear to represent the same thing. |

## Dynamic Workflow

1. Scan source.
2. Parse source into typed `CredentialObservation` values.
3. Merge observations into the inventory graph.
4. Classify state from graph relationships.
5. Produce doctor findings from states.
6. Project the same graph into CLI commands and SwiftUI views.
7. Persist metadata references and user annotations only.

## Query Patterns

| Question | Graph Query |
| --- | --- |
| What credentials exist? | Credential nodes. |
| Where does this resolve from? | Outgoing `stored-in` and `observed-in` edges. |
| What is unhealthy? | Credential nodes with warning or error states. |
| What should I fix first? | Findings ordered by severity, expiry, and blast radius. |
| Is this duplicated? | `duplicates` edges and shared source fingerprints. |
| What can be safely committed? | Metadata nodes and edges without secret values. |

## Invariants

- A list is a projection of the graph, not an independent source of truth.
- A doctor issue references graph credential, state, and source relationships.
- A UI route is a graph filter plus selection.
- A CLI command is a graph query plus formatting.
- A source parser may add observations, but it may not silently repair metadata.
- A missing edge is meaningful and must not be filled with a fake default.

## First Implementation Boundary

The first graph implementation is intentionally small:

- credential nodes
- source nodes
- state nodes
- `stored-in`, `observed-in`, and `has-state` edges
- deterministic construction from `CredentialObservation`
- compatibility construction from `CredentialRecord`
- environment variable scanning through `EnvironmentScanner`
- shell profile scanning through `ShellProfileScanner`
- config file scanning through `ConfigFileScanner`
- Keychain item reference scanning through `KeychainInventoryScanner`
- local graph composition through `LocalInventoryGraphBuilder`
- `scan env` projects observations through `InventoryGraph`
- `scan shell` projects observations through `InventoryGraph`
- `scan config` projects observations through `InventoryGraph`
- `scan keychain` projects item references through `InventoryGraph`
- `list` and `where` project credentials through `CredentialProjection`
- normal macOS app runs use settings-driven local graph input
- doctor findings through `CredentialDoctor.inspect(InventoryGraph)`
- metadata-Keychain reconciliation through `CredentialInventoryReconciler`

Findings, tags, and duplicate edges can be added when the doctor and UI need them.
