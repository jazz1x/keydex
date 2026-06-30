# Keydex Goals

Keydex is a Mac developer credential inventory. It exists to reduce local operating
fatigue without becoming a vault.

## Product Thesis

Developer credentials are scattered across Keychain, shell profiles, environment
variables, config files, and tool-specific stores. The hard part is not remembering the
secret value. The hard part is knowing which credential exists, where it resolves from,
whether it is stale, and what should be fixed next.

Keydex owns that inventory graph.

## Goals

| ID | Goal | Success Signal |
| --- | --- | --- |
| G1 | Show the real credential inventory on one Mac | Keychain, shell, env, and config observations resolve into one typed graph. |
| G2 | Make unhealthy states visible | Missing, plaintext, orphan, expiring, expired, and duplicate states are visible in CLI and UI. |
| G3 | Explain every finding | Doctor output always includes cause and action. |
| G4 | Keep secret values out of Keydex metadata | Metadata stores references and observations, never secret values. |
| G5 | Make the Mac app feel native | SwiftUI surfaces follow the design system, Human Interface Guidelines, and Liquid Glass hierarchy. |
| G6 | Keep CLI and UI behavior aligned | State labels, doctor language, and scan scope stay shared across app and CLI. |
| G7 | Make workflow dynamic through graph traversal | Views and commands filter the same inventory graph instead of maintaining separate lists. |
| G8 | Ship behind guardrails | Local hooks and CI verify code, docs, security, and project-contract drift. |

## Non-Goals

| ID | Non-Goal | Reason |
| --- | --- | --- |
| N1 | Password manager | Keydex inventories credentials; it does not own secret storage. |
| N2 | Secret sync | Cross-device or team sync would change the trust boundary. |
| N3 | Browser extension | The first scope is developer tooling on one Mac. |
| N4 | Team administration | Personal operating fatigue comes first. |
| N5 | Copy-secret-first UX | The primary action is understanding and repair, not secret extraction. |

## Milestones

| Milestone | Outcome | Gate |
| --- | --- | --- |
| M0 Foundation | Package, CLI shell, docs, CI, public repo, branch protection | `make guard`, `make quality`, branch protection |
| M1 Inventory Graph | Source observations produce graph nodes and edges | source parser tests, observation graph tests, contract gate |
| M2 Doctor | Findings classify unhealthy graph states with cause and action | graph doctor tests, CLI output checks |
| M3 CLI | `list`, `where`, `doctor`, and `scan` become useful for daily work | command tests, docs drift gate |
| M4 Mac App | Native SwiftUI inventory table, sidebar, inspector, and doctor panel | design review, accessibility pass |
| M5 Distribution | Signed downloadable app archive or DMG outside the App Store | release checklist, security scan |

Current milestone evidence lives in `PRODUCT-PLAN.md`. M4 has started, but it remains
incomplete until screen validation and accessibility evidence pass.

## Total Completion Gates

| Gate | Required Document | Required Evidence |
| --- | --- | --- |
| Product goal | `PRODUCT-PLAN.md` | Total goal questions have working CLI/UI answers. |
| Feature behavior | `FEATURE-SPEC.md` | Acceptance criteria pass for each feature. |
| Functional validation | `VALIDATION-SCENARIOS.md` | Required scenarios pass. |
| Screen validation | `SCREEN-VALIDATION.md` | Screenshots and accessibility evidence pass. |
| Release validation | `RELEASE-READINESS.md` | Release candidate checklist is complete. |
| Test strategy | `TESTING-STRATEGY.md` | Tests exist at the closest stable boundary. |

## Acceptance Rules

- Every new state label is added to philosophy, design, verification, CLI help, and tests.
- Every new source parser returns typed observations, not display strings.
- Every doctor finding has `severity`, `state`, `message`, and `action`.
- Every UI surface reads from the graph or a graph-derived projection.
- Every metadata field must be safe to commit to a repository.
- Every milestone has explicit feature and validation evidence.
- Every release candidate passes `make guard` and `make quality`.
