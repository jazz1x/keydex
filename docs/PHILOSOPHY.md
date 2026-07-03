# Keydex Philosophy

> Credentials should tell the truth about where they live.

Keydex is not a password manager. It is an inventory for Mac developer credentials. The
secret value belongs in macOS Keychain or another explicit secret store. Keydex owns the
map: references, metadata, sources, state, and doctor findings.

`SWIFT-STYLE.md` is the implementation contract for this philosophy: typed failures,
parse boundaries, and restrained abstractions are how the code keeps these claims true.

## Layer 1. The Representation Must Be True

State must not lie.

- `registered` means the Keychain item exists and metadata points to it.
- `plaintext-fallback` means a tool can still resolve the value from a file or shell
  profile. That is not "secure enough"; it is a visible state.
- `missing-keychain-item` means metadata points at nothing. The UI must not pretend the
  credential is healthy.
- `orphan` means a Keychain item exists without Keydex metadata.
- `expiring` means the credential is still usable but needs rotation soon.
- `expired` means the credential is no longer valid and must not be shown as healthy.
- `duplicate` means multiple observations appear to represent the same credential.

No raw `String` gets to masquerade as a service, account, location, or state once it has
crossed the input boundary. Parse once, then move typed values inward.

## Layer 2. The Flow Must Go One Way

Data enters from Keychain, shell files, environment, and config files. Each source is
parsed into typed observations. The doctor combines observations into states. The UI and
CLI display those states.

The flow does not reverse. UI code does not guess. Store code does not repair silently.
Fallbacks are facts to show, not shortcuts to hide.

## Layer 3. The Least Structure That Blocks the Most Lies

Keydex should stay thin.

- Do not build a vault.
- Do not sync secrets.
- Do not copy 1Password, Bitwarden, or Apple Passwords.
- Do not invent team sharing.
- Do not store secret values in metadata.

The high-leverage boundary is source parsing plus state classification. If that boundary is
honest, the rest of the app can stay small.

## Conflict Order

1. Honesty: the state must match reality.
2. Flow: data should move one way through typed boundaries.
3. Restraint: prefer the smaller structure after the first two are true.

When stuck, ask: **does this state lie?**
