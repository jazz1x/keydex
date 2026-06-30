# Release Readiness

Release readiness defines the evidence needed before publishing a Keydex CLI or Mac app
artifact.

## Release Channels

| Channel | Scope |
| --- | --- |
| GitHub source release | Tags, release notes, checks, source archive. |
| CLI binary | Built Swift executable for supported macOS versions. |
| Mac app archive or DMG | Downloadable app outside the App Store. |

## Release Gates

| Gate | Evidence |
| --- | --- |
| Branch protection | Release commit is on protected `main`. |
| CI | `guard`, `quality`, `gitleaks`, and `trivy` pass. |
| Local verification | `make guard` and `make quality` pass. |
| Functional scenarios | Required scenarios in `VALIDATION-SCENARIOS.md` pass. |
| Screen validation | Required scenarios in `SCREEN-VALIDATION.md` pass for app releases. |
| Release smoke | `make release-smoke` creates and inspects a local archive. |
| Secret boundary | Release artifacts contain no secret-bearing metadata. |
| Documentation | README, product plan, feature spec, and release notes match behavior. |

## Packaging Decisions

| Decision | Current Position |
| --- | --- |
| App Store | Out of scope for first release. |
| Developer ID signing | Required before public Mac app release if feasible. |
| Notarization | Required before public Mac app release if feasible. |
| DMG | Preferred user-facing app download format. |
| Zip archive | Acceptable for early internal app builds. |
| CLI install | GitHub release artifact first; Homebrew formula can come later. |

The first local release smoke is `scripts/release-smoke.sh`. It builds release-mode
SwiftPM products, writes a local archive under `tmp/release-smoke`, runs the packaged CLI,
and verifies fixture metadata is not included. It is not a substitute for Developer ID
signing, notarization, or the final DMG gate.

## Release Candidate Checklist

| Step | Evidence |
| --- | --- |
| Version chosen | Tag name and release notes draft. |
| Clean tree | `git status --short --branch`. |
| Tests | `make guard`. |
| Quality | `make quality`. |
| Security | CI `gitleaks` and `trivy`. |
| CLI smoke | `keydex --help`, `scan env`, `scan shell`, `doctor`. |
| App build | Xcode or SwiftPM app build evidence. |
| Screen proof | Required screenshots and accessibility notes. |
| Release smoke | `make release-smoke` output manifest and archive file list. |
| Artifact inspection | Confirm archive/DMG contains expected files only. |
| Publish | GitHub release created from protected `main`. |

## Release Notes Template

```markdown
## Summary

## Changes

## Verification

- make guard:
- make quality:
- CI:
- Functional scenarios:
- Screen validation:
- Security:

## Known Limits
```

## Rollback

Releases are immutable evidence points. If a release is wrong:

1. Do not rewrite the tag unless the artifact was never consumed.
2. Mark the release as withdrawn.
3. Publish a fixed release with a new version.
4. Document the incorrect behavior and verification gap.

## Completion Rule

M5 is not complete until release evidence proves build, function, screen, security,
documentation, and artifact checks.
