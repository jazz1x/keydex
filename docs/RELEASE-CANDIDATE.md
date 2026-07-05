# Release Candidate

This document is the working release-candidate evidence point for Keydex. It records
what can be published, what has been verified, and what still blocks a public Mac app
release.

## Current Candidate

| Field | Value |
| --- | --- |
| Channel | GitHub pre-release candidate. |
| App artifact | Ad-hoc signed app bundle inside an unsigned DMG smoke artifact. |
| CLI artifact | Release-mode Swift executable in the release-smoke archive. |
| Public release status | Not publishable as a trusted Mac app yet. |

## Release Notes Draft

### Summary

Keydex is a native Mac credential inventory for developers. It shows credential
references, source locations, unhealthy states, and repair guidance without storing secret
values.

### Changes

- Inventory graph covers environment, shell profile, config file, metadata, and Keychain
  observations.
- CLI supports metadata-backed `list`, `where`, `doctor`, and `scan` flows.
- Mac app shell renders graph-derived inventory, inspector, Doctor, settings, duplicate,
  empty, expiring, and expired states.
- Local app screen evidence covers the required scenario set owned by
  `scripts/app-evidence-scenarios.sh`, with `make app-screen-evidence-review` as the
  review gate.
- Release smoke builds release-mode CLI and app products, creates an app bundle, ad-hoc
  signs it, creates an unsigned DMG, writes checksums, and verifies artifact boundaries.

### Verification

| Evidence | Source |
| --- | --- |
| Build and tests | `make guard`. |
| Drift and contracts | `make quality`. |
| Release artifact smoke | `make release-smoke`. |
| Signing readiness | `make release-signing-readiness` before public app release. |
| Signing evidence | `make release-signing-evidence-review` before claiming a trusted Mac app release. |
| Required CI | `guard`, `quality`, `release-smoke`, `gitleaks`, `trivy`. |
| Screen evidence | `make app-screen-evidence-all` plus `make app-screen-evidence-review` are current for the required scenario set. |
| Accessibility evidence | Source-level `make app-accessibility-contract` passes; runtime `make app-accessibility-smoke` and manual review (52 fields across 13 scenarios) remain pending on a permissioned Mac session. |
| Security boundary | `gitleaks`, `trivy`, forbidden-pattern scan, release artifact inspection. |

### Known Limits

- App bundle uses ad-hoc signing only.
- DMG is unsigned.
- Developer ID signing is not complete.
- Notarization is not complete.
- Local signing readiness is blocked when the `Developer ID Application` identity,
  `notarytool`, or `stapler` prerequisite is unavailable.
- Screen evidence is current locally with `make app-screen-evidence-review` passing for
  the required scenario set; it is not produced in CI.
- Manual accessibility evidence is pending (52 fields across 13 scenarios); runtime
  `make app-accessibility-smoke` requires macOS accessibility trust for the host.
- Homebrew distribution is out of scope for the first release.

## Publish Blockers

| Blocker | Required Evidence |
| --- | --- |
| Developer ID signing | `codesign --verify` against the Developer ID signed app. |
| Notarization | `xcrun notarytool` success and stapled ticket evidence from `SIGNING-NOTARIZATION.md`. |
| Final DMG | Signed and notarized DMG or documented fallback decision. |
| Release tag | Protected `main` tag and GitHub release notes. |
| Screen proof | `make app-screen-evidence-review` passes for required screenshots. |
| Accessibility proof | `make app-accessibility-evidence-review` passes after manual VoiceOver, keyboard, state-not-color-only, and dynamic type review. |

## Completion Rule

This candidate can become a public Mac app release only after the publish blockers are
resolved or explicitly deferred in `RELEASE-READINESS.md`.
A deferred signing decision may describe a pre-signing artifact, but it must not call the
candidate trusted or M5 complete while `release_signing_readiness` or
`release_signing_evidence` are not `pass` in `make evidence-status`.
