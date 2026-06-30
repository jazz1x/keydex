# KeydexApp

SwiftUI macOS app surface shell.

`KeydexApp` is a local SwiftPM executable target under
`/Apps/KeydexApp/Sources/KeydexApp`.

## What it is

An app-shell-only interface that renders graph-derived credential projections
from `KeydexCore.InventoryGraph` and `CredentialProjection`.

## Settings Shell

The macOS shell now includes a non-mutating Settings sheet (toolbar gear button)
showing sample controls for:

- Keychain permission/status
- Source scan toggles (Keychain, Shell, Environment, Config)
- Scan paths
- Ignored/unmanaged source lists

All values are sample-only and read-only by design (no runtime keychain access).

## Local Run

From the repository root:

- `swift run KeydexApp`

Notes:

- This shell uses sample graph data only.
- It does not read secrets and does not access the live keychain.
- It now renders a native Doctor panel in the shell (`CredentialDoctor().inspect(graph)`) showing
  severity, credential, state, cause, and action for each detected issue.
- It also exposes a toolbar search to filter graph-derived credential rows by service, account,
  state raw value, and source location labels.
