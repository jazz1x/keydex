# KeydexApp

SwiftUI macOS app surface shell.

`KeydexApp` is a local SwiftPM executable target under
`/Apps/KeydexApp/Sources/KeydexApp`.

## What it is

An app-shell-only interface that renders graph-derived credential projections
from `KeydexCore.InventoryGraph` and `CredentialProjection`.

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
AX smoke do not drift with personal local state. The shell still avoids runtime keychain
access.

The Settings sheet uses a glass-style header, segmented section rail, and grouped list
sections so scan and reminder controls feel native without becoming a dashboard. Reminder
controls store safe metadata defaults only; they do not store secret values.

## Local Run

From the repository root:

- `swift run KeydexApp`

Notes:

- This shell uses graph-derived sample data by default and supports an empty dataset mode.
- It does not read secrets and does not access the live keychain.
- It now renders a native Doctor panel in the shell (`CredentialDoctor().inspect(graph)`) showing
  severity, credential, state, cause, and action for each detected issue.
- It also exposes a toolbar search to filter graph-derived credential rows by service, account,
  state raw value, and source location labels.

The toolbar includes a native segmented `Sample / Empty` control that swaps between:

- Sample: populated `InventoryGraph` produced by `sampleCredentialGraph()`
- Empty: empty `InventoryGraph(records: [])`, producing no credentials and no doctor issues
