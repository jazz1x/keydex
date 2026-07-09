# KeydexApp

SwiftUI macOS app surface shell.

`KeydexApp` is a local SwiftPM executable target under
`/Apps/KeydexApp/Sources/KeydexApp`.

## What it is

A native macOS interface that renders graph-derived credential projections from
`KeydexCore.InventoryGraph` and `CredentialProjection`. Normal app runs build the
local graph through `KeydexRuntime.LocalInventoryGraphBuilder`; screen evidence runs
keep deterministic sample data so visual and accessibility checks do not drift with
personal machine state.

## Settings Shell

The macOS shell now includes a material-backed Settings sheet (toolbar gear button) with
local controls for:

- Keychain permission/status
- Source scan toggles (Keychain, Shell, Environment, Config)
- Editable scan paths
- Expiry reminder defaults for safe `notifyBeforeDays` metadata
- Editable ignored/unmanaged source lists

Values persist as local settings metadata under Application Support for normal app runs.
Evidence scenarios keep using deterministic in-memory sample settings so screenshots and
AX smoke do not drift with personal local state. Normal Local runs can read live Keychain
item references when access is enabled, but secret values remain outside Keydex.

The Settings sheet uses a glass-style header, segmented section rail, and grouped list
sections so scan and reminder controls feel native without becoming a dashboard. Reminder
controls store safe metadata defaults only; they do not store secret values.

## Local Run

From the repository root:

- `swift run KeydexApp`

Notes:

- Normal app runs use the `Local` inventory source by default.
- Evidence runs and explicit toolbar selection can still use graph-derived sample data or
  an empty dataset mode.
- If Local has no indexed credentials yet, the empty state points to Settings and
  Refresh rather than describing the explicit empty evidence fixture.
- It does not store secrets. When Keychain access is enabled, it reads live item
  references only and omits secret values.
- If runtime Keychain prompt is enabled, Local refresh asks before reading live
  Keychain references.
- It now renders a native Doctor panel in the shell (`CredentialDoctor().inspect(graph)`) showing
  severity, credential, state, cause, and action for each detected issue.
- It also exposes a toolbar search to filter graph-derived credential rows by service, account,
  state raw value, and source location labels.

The toolbar includes a native segmented inventory source control that swaps between:

- Local: settings-driven `InventoryGraph` from `MacLocalInventoryGraphBuilder`
- Sample: populated `InventoryGraph` produced by `sampleCredentialGraph()`
- Empty: empty `InventoryGraph(records: [])`, producing no credentials and no doctor issues
