# Verification

Keydex treats verification as part of the product. A credential inventory that cannot
prove its own contract will drift into wishful UI.

## Gates

| Gate | Command or Setting | Verifies |
| --- | --- | --- |
| Format | `swift-format lint --recursive --strict Package.swift Sources Tests Apps` | Swift style stays stable. |
| Tests | `swift test` | Domain, graph, source parser, and doctor behavior. |
| App Build | `swift build --product KeydexApp` | SwiftUI Mac app shell compiles against graph projections. |
| App Window Smoke | `scripts/app-window-smoke.sh` | SwiftUI Mac app shell launches a default local window. |
| Forbidden Patterns | `scripts/forbidden-patterns.sh` | No silent `try?`, empty `catch`, or obvious secret-value metadata. |
| Project Contract | `scripts/project-contract.sh` | Goals, planning pack, design system, graph workflow, verification docs, and README links stay aligned. |
| Quality | `make quality` | CLI docs, state taxonomy, workflow wiring, and project contract. |
| CLI Smoke | `scripts/cli-smoke.sh` | Fixture-backed `list`, `where`, `doctor`, and `scan config` outputs. |
| Release Smoke | `scripts/release-smoke.sh` | Release-mode artifacts run locally, checksum cleanly, and omit fixture metadata. |
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
| PR checks | `guard`, `quality`, `gitleaks`, and `trivy` pass. |
| Planning pack | Product plan, feature spec, validation scenarios, screen validation, testing strategy, and release readiness remain aligned. |
| Branch state | Work merges through PR into `main`. |
| Distribution | Archive or DMG contains no secret-bearing metadata and has checksum evidence. |

## Failure Rule

When a verification point fails, fix the root cause first. Add retries, timeouts,
defensive guards, or fallbacks only after the root cause is named and the project contract
still has one source of truth.
