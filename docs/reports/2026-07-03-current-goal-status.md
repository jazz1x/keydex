# Current Goal Status

Date: 2026-07-03
Evidence baseline SHA: `7e0f25b`
Git dirty state: `clean`

This report records the latest product and evidence baseline after the settings scroll
inset merge. A report-only commit may have a later SHA without changing the evidence
baseline.

## BLUF

Keydex has a guarded first product boundary: graph-based credential inventory, CLI
projection, SwiftUI Mac app shell, screen evidence, runtime AX smoke, release smoke, and
branch-protected PR workflow are all active on protected `main`.

The total goal is not complete. Two evidence classes remain outside the automated loop:

- Manual accessibility evidence is still pending for VoiceOver, keyboard traversal,
  state-not-color-only review, and dynamic type across 13 scenarios.
- Developer ID signing and notarization remain blocked by missing local signing identity
  and notary credentials.

## Recently Merged PRs

| PR | Main SHA | Result |
| --- | --- | --- |
| #129 | `0cb2f4f` | Added per-scenario diagnostics to runtime AX smoke output. |
| #130 | `040ff8c` | Updated the current goal status report. |
| #131 | `2da2bac` | Clarified the goal report baseline semantics. |
| #132 | `56adf75` | Blocked settings modal background hits and toolbar activation. |
| #133 | `816fe85` | Classified missing signing identity/tool prerequisites as blocked evidence. |
| #134 | `9f6ed36` | Guarded the loop contract against automation sprawl. |
| #135 | `b01189d` | Clarified non-secret signing readiness scope. |
| #136 | `7e0f25b` | Added settings scroll bottom inset for long settings sections. |

## Goal Matrix

| Goal | Status | Current Evidence |
| --- | --- | --- |
| G1 Real Mac credential inventory | First boundary complete | Env, shell, config, metadata, and Keychain observations feed `InventoryGraph`. |
| G2 Unhealthy states visible | Guarded | CLI and app surfaces show missing, plaintext, orphan, expiring, expired, and duplicate states. |
| G3 Findings explain cause and action | Guarded | Doctor tests and CLI smoke cover graph-derived finding fields. |
| G4 No secret metadata | Guarded | Store tests, forbidden pattern scan, gitleaks, and release smoke protect the boundary. |
| G5 Native Mac app | Evidence-gated | SwiftUI app, Liquid Glass/HIG design contracts, screen evidence, and runtime AX smoke pass; manual accessibility evidence remains pending. |
| G6 CLI/UI alignment | Guarded | Shared state taxonomy, graph projections, CLI smoke, and app evidence scenarios are under `make quality`. |
| G7 Graph traversal workflow | First boundary complete | Search, detail, inspector, doctor, and CLI commands derive from graph projections. |
| G8 Guardrails | Strong | `guard`, `quality`, branch protection, PR-only workflow, screen review, AX smoke, release smoke, and evidence-status gates are active. |
| G9 Expiry operational | First boundary complete | Metadata expiry and reminder planner tests pass; reminders CLI scenario is covered. |

## Milestone Status

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 Foundation | Complete | Repo, docs, CI, branch protection, planning pack, public workflow. |
| M1 Inventory Graph | Complete for first scope | Typed observations and metadata records project into graph nodes and edges. |
| M2 Doctor | Complete for first scope | Graph-derived findings classify unhealthy states with severity, cause, and action. |
| M3 CLI | Complete for daily-work boundary | `scan`, `list`, `where`, `doctor`, and `reminders` are fixture-smoked. |
| M4 Mac App | Evidence-gated, not final | App build, design contract, UX flow contract, screen evidence, full AX smoke, and pending accessibility templates exist. Manual accessibility review remains. |
| M5 Distribution | Pre-signing ready, not public-ready | Release smoke creates ad-hoc app and unsigned DMG. Developer ID signing/notarization remain blocked. |

## Current Verification

| Check | Current Result |
| --- | --- |
| `make evidence-status` | Pass on `7e0f25b`; screen evidence pass, manual accessibility pending, signing blocked, `needs_attention=0`. |
| `make app-accessibility-evidence-status` | Pass on `7e0f25b`; 13 scenarios, 52 pending fields. |
| `make app-screen-evidence-review` | Pass on `7e0f25b`; all 13 scenario PNGs and manifests current. |
| `make release-smoke` | Pass on `7e0f25b`; release CLI/app build, ad-hoc app signing, archive, checksum, unsigned DMG, and DMG verification passed. |
| `make app-accessibility-smoke` | Pass on `7e0f25b`; all 13 scenarios expose expected AX text and settings modal toolbar controls remain hidden from AX. |
| PR CI | #136 merged after green `guard`, `quality`, `release-smoke`, `gitleaks`, and `trivy`. |

## Remaining Blockers

| Blocker | Current Status | Needed To Clear |
| --- | --- | --- |
| Manual accessibility evidence | Pending | Run scenario review with VoiceOver, keyboard traversal, state-not-color-only checks, and dynamic type notes; update each manifest field to `pass`; run `make app-accessibility-evidence-review`. |
| Developer ID signing readiness | Blocked | Install or enable a local `Developer ID Application` signing identity, then rerun `make release-signing-readiness`. |
| Notarization evidence | Blocked by signing readiness | Store notary credentials, sign the app, submit and staple the DMG, then run `make release-signing-evidence-review`. |

## Next Practical Step

The next code-local improvement is small: keep increasing failure diagnosability and
evidence fidelity without converting manual blockers into false passes.

The next total-goal step is not code-local: either perform the manual accessibility review
or provide Developer ID/notary credentials. Until then, Keydex should remain described as
pre-release ready rather than publicly release complete.
