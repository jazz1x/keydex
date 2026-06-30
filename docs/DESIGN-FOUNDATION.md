# Design Foundation

Keydex should feel like a Mac utility that always belonged on the system.

## North Star

Keydex is Finder plus Keychain Access plus Xcode Issues for developer credentials.

- Finder: familiar sidebar, table, inspector, toolbar.
- Keychain Access: domain model reference, not UX reference.
- Xcode Issues: risk states are actionable and hard to miss.
- System Settings: preferences, permissions, and privacy language.

## Layout

- Sidebar: scopes such as All, Expiring, Plaintext, Orphans, Tags, and Services.
- Content: dense credential table optimized for scanning.
- Inspector: selected credential details, sources, expiry, notes, and actions.
- Doctor panel: grouped issues with cause and next action.
- Toolbar: search, scan, register, doctor.

## Liquid Glass

Liquid Glass is hierarchy, not decoration.

- Use it for sidebar, toolbar, inspector, popovers, and command surfaces.
- Do not use it for every row or repeated table cell.
- Credential tables prioritize legibility over visual effect.
- Warning colors are reserved for real risk states.

## Language

Use state names consistently across CLI and UI.

- `registered`
- `missing-keychain-item`
- `plaintext-fallback`
- `orphan`
- `expiring`
- `expired`
- `duplicate`

Every doctor issue must show both cause and action.

## Anti-Goals

- No dashboard theater.
- No decorative cards inside cards.
- No secret-manager cosplay.
- No primary "copy secret" hero action.
