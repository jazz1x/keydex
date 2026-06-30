# Swift Style

This document is the concrete "how" for `docs/PHILOSOPHY.md`.

## Defaults

- SwiftUI for the Mac app.
- Observation for view state.
- `async`/`await` for asynchronous work.
- `throws` and typed domain errors for failure.
- Swift Argument Parser for the CLI.
- Security.framework for Keychain access.

RxSwift is not part of new code. Combine is allowed only when an Apple API naturally
emits publishers or when a real stream needs it.

## State

- Use enums for states. Do not model credential state as independent boolean flags.
- Keep raw strings at the boundary. Parse into types before domain logic sees them.
- Prefer private initializers plus `parse` factories for values with invariants.

## Errors

- Domain errors live in typed enums.
- UI boundaries may aggregate multiple validation errors when showing one-at-a-time would
  make the user fix the same form repeatedly.
- Do not use `try?` to erase failure.
- Do not use empty `catch` blocks.

## Boundaries

- Keychain, filesystem, environment, and clock access are I/O boundaries.
- Pure classification logic takes values in and returns values out.
- Add protocols where a second implementation exists or tests need isolation.
- Do not add abstraction for a single pure implementation.

## UI

- UI code displays states; it does not invent them.
- The primary action is diagnosis and location, not copying secret values.
- Copying a secret, if added later, must be deliberately secondary.
