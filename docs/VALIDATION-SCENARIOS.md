# Validation Scenarios

Validation proves Keydex behavior from the product contract down to CLI, source parsing,
doctor findings, security boundaries, and future UI.

## Validation Layers

| Layer | Evidence |
| --- | --- |
| Build | `make guard`, `swift test`, Swift compiler, Swift format. |
| Quality | `make quality`, `scripts/project-contract.sh`. |
| Security | gitleaks, trivy, forbidden-pattern scan. |
| Philosophy | Review checklist proves state truth, graph projection, no secret ownership. |
| Functional | Unit, fixture, and CLI scenario tests. |
| Screen | Screenshot, accessibility, and HIG/Liquid Glass checks. |
| Release | Release readiness checklist and CI evidence. |

## Build Scenarios

| ID | Scenario | Evidence |
| --- | --- | --- |
| B1 | Package builds on macOS CI. | `guard` GitHub Action passes. |
| B2 | Swift format is strict. | `swift-format lint --recursive --strict Package.swift Sources Tests Apps`. |
| B3 | Unit tests pass. | `swift test`. |
| B4 | CLI help remains documented. | `make quality` command inventory drift check. |
| B5 | Project contract remains linked. | `scripts/project-contract.sh`. |

## Philosophy Scenarios

| ID | Scenario | Evidence |
| --- | --- | --- |
| P1 | State does not lie. | State labels in docs, tests, and CLI match canonical taxonomy. |
| P2 | Lists are graph projections. | CLI and UI paths use `InventoryGraph`. |
| P3 | Secret values are not owned. | Tests prove scanner outputs omit secret values. |
| P4 | Fallback is visible. | Env/shell/config plaintext observations become `plaintext-fallback`. |
| P5 | Repair is explicit. | Doctor emits action text; mutation flows require user action. |

## Functional Scenarios

| ID | Scenario | Required Result |
| --- | --- | --- |
| F1 | Empty inventory | CLI and UI show honest empty state. |
| F2 | Env plaintext credential | `scan env` emits `plaintext-fallback` observation without value. |
| F3 | Shell plaintext credential | `scan shell` emits `plaintext-fallback` observation without value. |
| F4 | Config plaintext credential | `scan config` emits observation without value. |
| F5 | Keychain registered credential | Graph has `stored-in` edge and `registered` state. |
| F6 | Missing Keychain item | Doctor emits `missing-keychain-item` error. |
| F7 | Orphan Keychain item | Doctor emits `orphan` warning. |
| F8 | Duplicate credential | Doctor emits `duplicate` warning. |
| F9 | Expiring credential | Doctor emits `expiring` warning with rotation action. |
| F10 | Expired credential | Doctor emits `expired` error. |
| F11 | `where` query | CLI shows graph-derived source relationships. |
| F12 | `list` query | CLI shows graph-derived credential rows. |
| F13 | Doctor issue shape | Every issue includes severity, credential, state, locations, cause, action. |
| F14 | Store persistence | Store persists metadata only. |
| F15 | Ignore rule | Ignored source or credential is excluded from active repair queue. |

## CLI Scenario Matrix

| Command | Fixture | Expected Evidence |
| --- | --- | --- |
| `scan env` | Process env with credential-like names | Counts credentials, sources, edges; no values. |
| `scan shell` | Shell profile fixture | Counts credentials, sources, edges; no values. |
| `scan config --path fixture.env` | Config fixture | Counts credentials, sources, edges; no values. |
| `list --metadata fixture.json` | Store fixture | Prints service/account/state/source count. |
| `where openai --metadata fixture.json` | Store fixture | Prints env/shell/config/Keychain locations. |
| `doctor --metadata fixture.json` | Store fixture with unhealthy states | Prints severity, credential, state, cause, action. |

## Security Scenarios

| ID | Scenario | Evidence |
| --- | --- | --- |
| S1 | Scanner receives secret value | Observation debug output does not contain value. |
| S2 | Store writes metadata | Stored fixture contains no secret value field. |
| S3 | CI secret scan | `gitleaks` passes. |
| S4 | Dependency/security scan | `trivy` passes. |
| S5 | Forbidden code patterns | Forbidden-pattern scan passes. |

## Screen Scenarios

Screen validation details live in `SCREEN-VALIDATION.md`. Functional release cannot be
called complete until screen scenarios have screenshot and accessibility evidence.

## Release Scenarios

Release validation details live in `RELEASE-READINESS.md`. Distribution cannot be called
complete until release evidence is attached to the release candidate.
