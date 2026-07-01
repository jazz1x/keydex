# Design Foundation

Keydex should feel like a Mac utility that always belonged on the system.

## North Star

Keydex is Finder plus Keychain Access plus Xcode Issues for developer credentials.

- Finder: familiar sidebar, table, inspector, toolbar.
- Keychain Access: domain model reference, not UX reference.
- Xcode Issues: risk states are actionable and hard to miss.
- System Settings: preferences, permissions, and privacy language.
- Graph tools: every view is a projection of credential, source, state, and finding
  relationships.

## Layout

- Sidebar: scopes such as All, Expiring, Plaintext, Orphans, Tags, and Services.
- Content: dense credential table optimized for scanning.
- Inspector: selected credential details, sources, expiry, notes, and actions.
- Doctor panel: grouped issues with cause and next action.
- Toolbar: search, scan, register, doctor.

## Design System

The detailed component and token contract lives in [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md).
The graph-driven product workflow lives in [GRAPH-WORKFLOW.md](GRAPH-WORKFLOW.md).

## Liquid Glass

Liquid Glass is hierarchy, not decoration.

- Use it for sidebar, toolbar, popovers, command surfaces, and credential card shells.
- Do not use it for every row or dense detail section.
- Credential cards use low-tint native glass shells plus stronger poster-style state art.
- Card backdrops stay plain like Apple Music library content; no graph, constellation,
  path-line, or analytics substrate is allowed behind cards.
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
