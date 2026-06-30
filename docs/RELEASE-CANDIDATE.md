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
- Local app screen evidence covers required default, empty, search, inspector, settings,
  and compact scenarios with a review gate.
- Release smoke builds release-mode CLI and app products, creates an app bundle, ad-hoc
  signs it, creates an unsigned DMG, writes checksums, and verifies artifact boundaries.

### Verification

| Evidence | Source |
| --- | --- |
| Build and tests | `make guard`. |
| Drift and contracts | `make quality`. |
| Release artifact smoke | `make release-smoke`. |
| Required CI | `guard`, `quality`, `release-smoke`, `gitleaks`, `trivy`. |
| Screen evidence | `scripts/app-screen-evidence.sh` local output plus `make app-screen-evidence-review` before app release. |
| Security boundary | `gitleaks`, `trivy`, forbidden-pattern scan, release artifact inspection. |

### Known Limits

- App bundle uses ad-hoc signing only.
- DMG is unsigned.
- Developer ID signing is not complete.
- Notarization is not complete.
- Screen evidence remains local and manual, but the required manifest and screenshot set
  is review-gated.
- Homebrew distribution is out of scope for the first release.

## Publish Blockers

| Blocker | Required Evidence |
| --- | --- |
| Developer ID signing | `codesign --verify` against the Developer ID signed app. |
| Notarization | `xcrun notarytool` success and stapled ticket evidence from `SIGNING-NOTARIZATION.md`. |
| Final DMG | Signed and notarized DMG or documented fallback decision. |
| Release tag | Protected `main` tag and GitHub release notes. |
| Screen proof | Required screenshots, `make app-screen-evidence-review`, and accessibility notes from `SCREEN-VALIDATION.md`. |

## Completion Rule

This candidate can become a public Mac app release only after the publish blockers are
resolved or explicitly deferred in `RELEASE-READINESS.md`.
