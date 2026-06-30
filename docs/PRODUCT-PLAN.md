# Product Plan

Keydex is a native Mac developer credential inventory. It helps one developer answer
what credentials exist on the Mac, where they resolve from, what is unhealthy, and what
to fix next.

## Target User

| User | Need |
| --- | --- |
| Mac developer | See credentials scattered across Keychain, shell profiles, environment variables, and config files. |
| Tool maintainer | Keep CLI and Mac UI behavior aligned through one graph model. |
| Future contributor | Add sources and UI views without weakening the secret boundary. |

## Problem

Credentials drift into multiple places:

- Keychain items without inventory metadata.
- Shell profile exports that become plaintext fallback.
- Environment variables that override expected secure storage.
- Config files that contain local credential references or values.
- Stale metadata pointing to a missing Keychain item.

The product must show the truth without becoming a password manager.

## Total Goal

Keydex is complete when it can safely answer:

| Question | Required Evidence |
| --- | --- |
| What credentials exist on this Mac? | CLI and Mac app list graph-derived credential nodes. |
| Where does each credential resolve from? | `where` and inspector show source relationships. |
| Which credentials are unhealthy? | Doctor findings classify graph states. |
| Why is each credential unhealthy? | Every finding includes cause and action. |
| What data is safe to store? | Store tests prove metadata excludes secret values. |
| Can CLI and UI agree? | Both surfaces use canonical state labels and graph projections. |
| Can releases prove correctness? | Build, functional, screen, security, and philosophy gates pass. |

## Product Principles

| Principle | Product Meaning |
| --- | --- |
| Truth first | Never call a credential healthy unless the graph proves it. |
| Graph first | Lists, screens, and commands are projections of one inventory graph. |
| No vault | Secret values stay in Keychain or explicit external secret stores. |
| Repair oriented | Unhealthy states lead to cause and action, not just warning labels. |
| Native Mac | The UI feels like a focused Mac utility, not a dashboard or web shell. |

## Milestone Plan

| Milestone | Outcome | Exit Criteria |
| --- | --- | --- |
| M0 Foundation | Repo, docs, CI, branch protection | Guardrails green on protected `main`. |
| M1 Inventory Graph | Observations become graph nodes and edges | Env and shell observations produce graph summaries. |
| M2 Doctor | Graph states become findings | Doctor emits severity, credential, state, cause, action, and locations. |
| M3 CLI | Daily CLI workflows work | `scan`, `list`, `where`, and `doctor` operate over graph/store fixtures. |
| M4 Mac App | Native SwiftUI inventory app | Sidebar, table, inspector, doctor panel, settings, screen validation pass. |
| M5 Distribution | Downloadable app and CLI release | Release readiness evidence is complete. |

## Current Position

| Milestone | State |
| --- | --- |
| M0 | Complete. |
| M1 | Complete for env, shell, config, and keychain discovery. |
| M2 | Complete for graph-based findings. |
| M3 | Complete for metadata-backed CLI commands and keychain reconciliation. |
| M4 | In progress with SwiftUI shell, graph-derived inventory surfaces, accessibility contract, runtime accessibility smoke, local screen evidence scenarios, screen evidence review gate, design contract, and accessibility evidence review gate. |
| M5 | In progress with local release smoke artifacts, ad-hoc app codesign evidence, unsigned DMG evidence, checksum evidence, and signing readiness gate; Developer ID signing and notarization remain incomplete. |

## Release Shape

Keydex ships outside the App Store:

- CLI binary for developer workflows.
- Native Mac app archive or DMG.
- Public GitHub repository.
- Required CI checks before every merge.
- Release notes that include verification evidence.

## Decisions

| Decision | Rationale |
| --- | --- |
| Full Swift | Keychain, SwiftUI, native Mac behavior, and distribution are Mac-specific. |
| No App Store first | Developer distribution through GitHub release/DMG is enough. |
| Graph as product core | Avoid duplicate truth between CLI, UI, and doctor. |
| Metadata only | Secret values must not become Keydex-owned data. |
| PR per logical unit | Each change proves one product movement and one verification surface. |

## Planning Pack

| Document | Role |
| --- | --- |
| `GOALS.md` | Product goals and milestone ladder. |
| `PRODUCT-PLAN.md` | Target user, total goal, release shape. |
| `FEATURE-SPEC.md` | Functional behavior and acceptance criteria. |
| `VALIDATION-SCENARIOS.md` | Functional, build, philosophy, and regression scenarios. |
| `SCREEN-VALIDATION.md` | Mac app visual and accessibility verification. |
| `RELEASE-READINESS.md` | Release evidence, packaging, and distribution checks. |
| `RELEASE-CANDIDATE.md` | Current release notes draft, evidence, limits, and publish blockers. |
| `SIGNING-NOTARIZATION.md` | Developer ID signing and notarization runbook. |
| `TESTING-STRATEGY.md` | Test layers and evidence rules. |
