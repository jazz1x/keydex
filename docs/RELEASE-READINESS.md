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
| CI | `guard`, `quality`, `release-smoke`, `gitleaks`, and `trivy` pass. |
| Local verification | `make guard` and `make quality` pass. |
| Functional scenarios | Required scenarios in `VALIDATION-SCENARIOS.md` pass. |
| Screen validation | Required scenarios in `SCREEN-VALIDATION.md` pass for app releases. |
| Release smoke | `make release-smoke` creates, ad-hoc signs, checksums, and inspects a local archive, app bundle, and unsigned DMG. |
| Signing readiness | `make release-signing-readiness` proves a local Developer ID Application identity, notarytool, and stapler are available before public app signing. |
| Signing evidence | `make release-signing-evidence-template` creates pending local evidence; `make release-signing-evidence-review` verifies signed/notarized artifacts. |
| Secret boundary | Release artifacts contain no secret-bearing metadata. |
| Documentation | README, product plan, feature spec, and release notes match behavior. |

## Packaging Decisions

| Decision | Current Position |
| --- | --- |
| App Store | Out of scope for first release. |
| Developer ID signing | Required before public Mac app release if feasible; ad-hoc signing is only a structure smoke. |
| Notarization | Required before public Mac app release if feasible. |
| DMG | Preferred user-facing app download format; unsigned DMG smoke is a pre-signing gate. |
| Zip archive | Acceptable for early internal app builds. |
| CLI install | GitHub release artifact first; Homebrew formula can come later. |

The first local release smoke is `scripts/release-smoke.sh`. It builds release-mode
SwiftPM products, writes a local archive, unsigned DMG, and SHA-256 checksums under
`tmp/release-smoke`, validates an app bundle with ad-hoc codesign, runs the packaged CLI,
and verifies fixture metadata is not included. It is not a substitute for Developer ID
signing or notarization.

Developer ID signing readiness is checked separately by
`scripts/release-signing-readiness.sh`. It must fail when the local Keychain does not
contain a `Developer ID Application` identity; that failure is the correct blocker before
public Mac app distribution.

After signing and notarization, use `make release-signing-evidence-template` to create the
local evidence shell, fill the notes and manifest with the actual commands/results, then
run `make release-signing-evidence-review`. The review gate checks exact manifest
key-value lines for the current Git SHA, dirty state, expected app and DMG paths,
Developer ID app signing, stapled notarization validation, and signed DMG checksum.

## Release Candidate Checklist

| Step | Evidence |
| --- | --- |
| Version chosen | Tag name and release notes draft. |
| Clean tree | `git status --short --branch`. |
| Tests | `make guard`. |
| Quality | `make quality`. |
| Security | CI `gitleaks` and `trivy`. |
| CI release smoke | CI `release-smoke`. |
| CLI smoke | `keydex --help`, `scan env`, `scan shell`, `doctor`. |
| App build | Xcode, SwiftPM app build, or ad-hoc app bundle smoke evidence. |
| Screen proof | Required screenshots, `make app-screen-evidence-review`, and accessibility notes. |
| Release smoke | `make release-smoke` output manifest, checksums, DMG, and archive file list. |
| Signing readiness | `make release-signing-readiness` output or explicit blocker note. |
| Signing evidence | `make release-signing-evidence-review` output after Developer ID signing and notarization. |
| Artifact inspection | Confirm archive/DMG contains expected files only. |
| Release notes | `RELEASE-CANDIDATE.md` is current. |
| Signing runbook | `SIGNING-NOTARIZATION.md` is current. |
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
