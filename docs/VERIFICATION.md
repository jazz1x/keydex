# Verification

Keydex treats verification as part of the product. A credential inventory that cannot
prove its own contract will drift into wishful UI.

## Gates

| Gate | Command or Setting | Verifies |
| --- | --- | --- |
| Format | `swift-format lint --recursive --strict Package.swift Sources Tests Apps` | Swift style stays stable. |
| Swift Style | `docs/SWIFT-STYLE.md`, `scripts/forbidden-patterns.sh`, `scripts/loop-contract.sh` | Typed failures, parse boundaries, and restrained abstraction rules stay visible in automated gates. |
| Tests | `swift test` | Domain, graph, source parser, runtime graph builder, doctor behavior, and app presentation stores. |
| App Build | `swift build --product KeydexApp` | SwiftUI Mac app shell compiles against graph projections and the local runtime builder. |
| App Window Smoke | `scripts/app-window-smoke.sh` | SwiftUI Mac app shell launches a stable default local window and reports its dimensions. |
| App Evidence Scenarios Contract | `scripts/app-evidence-scenarios-contract.sh` | Screen, accessibility evidence, runtime smoke, docs, and SwiftUI scenario raw values share one supported scenario source of truth. |
| App Screen Evidence Review | `scripts/app-screen-evidence-review.sh` | Local screenshot manifests and PNGs cover required screen scenarios for the current Git SHA and dirty state. |
| App Accessibility Smoke | `scripts/app-accessibility-smoke.sh` | Running app exposes the full shared scenario set through the macOS `AXUIElement` tree, using the same inventory mode, window preset, and settings scroll target as screen evidence; it covers card library, card detail, empty, search, inspector, settings subsections, compact window sizing, toolbar controls hidden from AX while settings is modal, and per-scenario diagnostics for local AX crashes. |
| App Accessibility Evidence Template | `scripts/app-accessibility-evidence-template.sh` | Pending local evidence files can be generated with scenario-specific review targets, or pending-only manifests can refresh SHA/dirty state without overwriting notes or falsely passing review. |
| App Accessibility Evidence Template Contract | `scripts/app-accessibility-evidence-template-contract.sh` | Pending accessibility evidence refresh preserves notes, rejects non-pending review fields, and upgrades legacy notes with Scenario Focus guidance. |
| App Accessibility Evidence Status | `scripts/app-accessibility-evidence-status.sh` | Current local accessibility evidence is listed per scenario and field, with notes and review audit keys present, and the next pending scenario/field/notes/screenshot set is reported so manual review work remains visible and resumable. |
| App Accessibility Evidence Review | `scripts/app-accessibility-evidence-review.sh` | Local VoiceOver, keyboard, state-label, and dynamic type evidence covers required screen scenarios for the current Git SHA and dirty state, with non-template reviewer and UTC ISO-8601 review timestamp. |
| App Design Contract | `scripts/app-design-contract.sh` | Native Mac utility structure, graph-derived repair surfaces, and anti-theater visual rules remain wired. |
| App UX Flow Contract | `scripts/app-ux-flow-contract.sh` | Daily Mac utility flow remains intact: orient, narrow, inspect, act, and configure without hiding manual blockers. |
| Forbidden Patterns | `scripts/forbidden-patterns.sh` | No silent `try?`, script-level `try!`, script command argument force unwraps, script window-list fallbacks, empty `catch`, obvious secret-value metadata, or fake secret literals in production source. |
| Loop Contract | `scripts/loop-contract.sh` | Clean Architecture import boundaries, package dependency boundaries, and loop documentation wiring remain aligned. |
| Project Contract | `scripts/project-contract.sh` | Goals, planning pack, design system, graph workflow, verification docs, and README links stay aligned. |
| Quality | `make quality` | CLI docs, state taxonomy, workflow wiring, project contract, loop contract, CLI smoke, app accessibility/design/UX flow contracts, app evidence scenario SSOT, accessibility/signing evidence template contracts, and menubar smoke script contract. |
| CLI Smoke | `scripts/cli-smoke.sh` | Fixture-backed `list`, `where`, `doctor`, `reminders`, and `scan config` outputs, including status symbols and scope labels. |
| Release Smoke | `scripts/release-smoke.sh` | Release-mode artifacts bundle locally, ad-hoc sign cleanly, create unsigned DMG smoke evidence, checksum cleanly, and omit fixture metadata plus fake secret sentinels. |
| Release Signing Readiness | `scripts/release-signing-readiness.sh` | Local Developer ID Application identity and Apple notarization tools exist before public app signing; missing local prerequisites are reported together. |
| Release Signing Evidence Template | `scripts/release-signing-evidence-template.sh` | Pending local evidence can be generated for Developer ID signing and notarization, or pending-only manifests can refresh SHA/artifact paths without overwriting notes or falsely passing review. |
| Release Signing Evidence Template Contract | `scripts/release-signing-evidence-template-contract.sh` | Pending signing evidence refresh preserves notes, updates current SHA/artifact paths, and rejects non-pending signing result fields. |
| Release Signing Evidence Review | `scripts/release-signing-evidence-review.sh` | Signed app, notarized/stapled DMG, checksum, release-candidate evidence, non-template reviewer, and UTC ISO-8601 review timestamp are verified for the current Git SHA and dirty state. |
| Evidence Status | `scripts/evidence-status.sh` | Current local evidence is summarized without replacing review gates: automatic evidence must be current, manual evidence can remain `pending` with pending scenario/field counts, and external signing prerequisites plus dependent signing evidence are reported as `blocked` with prerequisite status, next missing prerequisite, and runbook path until readiness passes. |
| Security | GitHub Actions `gitleaks` and `trivy` | Secret leaks, high-risk dependency and config findings. |
| Branch Protection | GitHub `main` protection | Required checks, PR flow, linear history, and force-push prevention. |

## Review Points

- Does this change make the inventory graph more truthful?
- Does this change add a source, node, edge, state, or projection?
- Does every doctor issue include credential, state, cause, and action?
- Does this change satisfy the relevant planning pack acceptance criteria?
- Is the new behavior verified at the closest stable boundary?
- Does the UI still use canonical state labels and risk semantics?
- Does any metadata field contain or imply a secret value?
- Does a fallback become visible instead of silent?

## Release Checklist

| Step | Required Evidence |
| --- | --- |
| Local gate | `make guard` passes. |
| Drift gate | `make quality` passes. |
| PR checks | `guard`, `quality`, `release-smoke`, `gitleaks`, and `trivy` pass. |
| Planning pack | Product plan, feature spec, validation scenarios, screen validation, testing strategy, and release readiness remain aligned. |
| Branch state | Work merges through PR into `main`. |
| Distribution | Archive and DMG contain no secret-bearing metadata, app codesign evidence, and checksum evidence. |

## Failure Rule

When a verification point fails, fix the root cause first. Add retries, timeouts,
defensive guards, or fallbacks only after the root cause is named and the project contract
still has one source of truth.
