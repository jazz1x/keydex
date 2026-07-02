# Verification

Keydex treats verification as part of the product. A credential inventory that cannot
prove its own contract will drift into wishful UI.

## Gates

| Gate | Command or Setting | Verifies |
| --- | --- | --- |
| Format | `swift-format lint --recursive --strict Package.swift Sources Tests Apps` | Swift style stays stable. |
| Tests | `swift test` | Domain, graph, source parser, and doctor behavior. |
| App Build | `swift build --product KeydexApp` | SwiftUI Mac app shell compiles against graph projections. |
| App Window Smoke | `scripts/app-window-smoke.sh` | SwiftUI Mac app shell launches a stable default local window and reports its dimensions. |
| App Screen Evidence Review | `scripts/app-screen-evidence-review.sh` | Local screenshot manifests and PNGs cover required screen scenarios for the current Git SHA and dirty state. |
| App Accessibility Smoke | `scripts/app-accessibility-smoke.sh` | Running app exposes core sidebar, table, doctor, inspector, settings, and state names through the macOS `AXUIElement` tree. |
| App Accessibility Evidence Template | `scripts/app-accessibility-evidence-template.sh` | Pending local evidence files can be generated for each required scenario without falsely passing review. |
| App Accessibility Evidence Review | `scripts/app-accessibility-evidence-review.sh` | Local VoiceOver, keyboard, state-label, and dynamic type evidence covers required screen scenarios for the current Git SHA and dirty state. |
| App Design Contract | `scripts/app-design-contract.sh` | Native Mac utility structure, graph-derived repair surfaces, and anti-theater visual rules remain wired. |
| Forbidden Patterns | `scripts/forbidden-patterns.sh` | No silent `try?`, empty `catch`, or obvious secret-value metadata. |
| Loop Contract | `scripts/loop-contract.sh` | Clean Architecture import boundaries, package dependency boundaries, and loop documentation wiring remain aligned. |
| Project Contract | `scripts/project-contract.sh` | Goals, planning pack, design system, graph workflow, verification docs, and README links stay aligned. |
| Quality | `make quality` | CLI docs, state taxonomy, workflow wiring, project contract, loop contract, CLI smoke, app accessibility/design contracts, and menubar smoke script contract. |
| CLI Smoke | `scripts/cli-smoke.sh` | Fixture-backed `list`, `where`, `doctor`, `reminders`, and `scan config` outputs, including status symbols and scope labels. |
| Release Smoke | `scripts/release-smoke.sh` | Release-mode artifacts bundle locally, ad-hoc sign cleanly, create unsigned DMG smoke evidence, checksum cleanly, and omit fixture metadata. |
| Release Signing Readiness | `scripts/release-signing-readiness.sh` | Local Developer ID Application identity and Apple notarization tools exist before public app signing. |
| Release Signing Evidence Template | `scripts/release-signing-evidence-template.sh` | Pending local evidence can be generated for Developer ID signing and notarization without falsely passing review. |
| Release Signing Evidence Review | `scripts/release-signing-evidence-review.sh` | Signed app, notarized/stapled DMG, checksum, and release-candidate evidence are verified for the current Git SHA and dirty state. |
| Evidence Status | `scripts/evidence-status.sh` | Current local evidence is summarized without replacing review gates: automatic evidence must be current, manual evidence can remain `pending`, and external signing prerequisites are reported as `blocked`. |
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
