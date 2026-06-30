# Signing And Notarization

This runbook defines the public Mac app release gate after `make release-smoke` passes.
It is intentionally separate from release smoke because Developer ID credentials are a
secret-bearing, account-specific boundary.

## Scope

| Topic | Position |
| --- | --- |
| Local smoke | `make release-smoke` uses ad-hoc app signing only. |
| Public app release | Requires Developer ID signing if feasible. |
| Public DMG release | Requires notarization and stapling if feasible. |
| Credential storage | Keychain or Apple tooling only; never repository files. |

## Required Inputs

| Input | Example Reference | Storage Rule |
| --- | --- | --- |
| Developer ID Application identity | `Developer ID Application: Name (TEAMID)` | Local signing identity in Keychain. |
| Notary profile | `keydex-notary` | Created with `xcrun notarytool store-credentials`. |
| Team ID | `TEAMID` | Reference only; not a secret value. |
| Release DMG | `tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg` | Generated artifact, not committed. |

## Credential Setup

Create or update the notary profile interactively:

```bash
xcrun notarytool store-credentials keydex-notary --team-id TEAMID
```

Use an App Store Connect API key or Apple ID app-specific password through the interactive
prompt or Apple tooling. Do not commit keys, passwords, or exported keychain items.

## Signing Flow

After release smoke has produced a candidate app bundle:

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: Name (TEAMID)" \
  tmp/release-smoke/keydex-<sha>-Darwin-arm64/Keydex.app

codesign --verify --deep --strict \
  tmp/release-smoke/keydex-<sha>-Darwin-arm64/Keydex.app
```

Recreate the DMG from the signed app bundle, then verify the image:

```bash
hdiutil create -volname "Keydex" \
  -srcfolder tmp/release-smoke/keydex-<sha>-Darwin-arm64/Keydex.app \
  -ov -format UDZO \
  tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg

hdiutil verify tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg
```

## Notarization Flow

Submit and wait for notarization:

```bash
xcrun notarytool submit \
  tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg \
  --keychain-profile keydex-notary \
  --wait
```

Staple and validate the ticket:

```bash
xcrun stapler staple tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg
xcrun stapler validate tmp/release-smoke/keydex-<sha>-Darwin-arm64.dmg
```

## Evidence

| Evidence | Required Command |
| --- | --- |
| Developer ID signature | `codesign --verify --deep --strict`. |
| Notary acceptance | `xcrun notarytool submit ... --wait`. |
| Stapled ticket | `xcrun stapler validate`. |
| Artifact checksum | `shasum -a 256`. |
| Release notes | `RELEASE-CANDIDATE.md`. |

## References

- Apple notarization overview: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Local command help: `xcrun notarytool --help`, `xcrun stapler --help`, `codesign --help`.

## Completion Rule

M5 can only move from pre-signing readiness to public Mac app readiness after the signed
and notarized artifact evidence is attached to `RELEASE-CANDIDATE.md`.
