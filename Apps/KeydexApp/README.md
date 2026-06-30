# KeydexApp

SwiftUI macOS app surface shell.

`KeydexApp` is a local SwiftPM executable target under
`/Apps/KeydexApp/Sources/KeydexApp`.

## What it is

An app-shell-only interface that renders graph-derived credential projections
from `KeydexCore.InventoryGraph` and `CredentialProjection`.

## Local Run

From the repository root:

- `swift run KeydexApp`

Notes:

- This shell uses sample graph data only.
- It does not read secrets and does not access the live keychain.
- It now renders a native Doctor panel in the shell (`CredentialDoctor().inspect(graph)`) showing
  severity, credential, state, cause, and action for each detected issue.
