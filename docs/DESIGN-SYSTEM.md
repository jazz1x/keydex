# Design System

Keydex should feel like a focused Mac utility: calm, inspectable, dense enough for work,
and honest about risk.

## Principles

| Principle | Meaning |
| --- | --- |
| Native first | Prefer SwiftUI system controls, platform spacing, keyboard behavior, and accessibility. |
| Graph visible | The UI shows relationships between credential, source, state, and finding. |
| Risk without theater | Warnings are clear, not decorative. Color only means something. |
| Dense but breathable | Tables and inspectors should support repeated daily scanning. |
| Repair oriented | Every unhealthy state points to the next action. |

## Visual Tokens

| Token | Value | Use |
| --- | --- | --- |
| `surface.primary` | system background | main content |
| `surface.sidebar` | Liquid Glass material | sidebar search, navigation, and scope filters |
| `surface.inspector` | native Liquid Glass, 8 px radius | selected item detail |
| `surface.card` | native Liquid Glass, 8 px radius | inventory cards and grouped settings only |
| `glass.sidebar.selection` | primary 0.055 alpha | selected sidebar rows |
| `glass.content.tint` | white 0.10 alpha | card and inspector glass shell tint |
| `glass.poster.tint` | semantic state color 0.30 alpha | card poster glass tint |
| `glass.floating.tint` | white 0.14 alpha | bottom repair rail tint |
| `artwork.state.tint` | semantic state color 0.30 alpha | card poster color field |
| `text.primary` | label | credential names and actions |
| `text.secondary` | secondary label | metadata and source paths |
| `risk.info` | blue | neutral findings |
| `risk.warning` | orange | plaintext, orphan, expiring, duplicate |
| `risk.error` | red | missing keychain item, expired |
| `spacing.row` | 8 px | table row vertical rhythm |
| `spacing.panel` | 16 px | inspector and popover padding |
| `radius.control` | system default | buttons, fields, segmented controls |
| `radius.card` | 8 px max | repeated issue rows only |
| `appearance.mode` | system light/dark | no product-level custom palettes |

## App Surfaces

| Surface | Role | Required Controls |
| --- | --- | --- |
| Sidebar | Scope navigation | All, Expiring, Plaintext, Orphans, Duplicates, Services, Tags |
| Toolbar | Global actions | search, scan, register, display mode, doctor, settings |
| Inventory Table | Primary working view | grouped list rows, selected pill, sortable columns, state chips, source count, last observed |
| Inventory Cards | Secondary scan view | poster-style credential surface, state chips, Keychain badge, source previews |
| Inspector | Relationship detail | credential, sources, graph edges, expiry, notes, actions |
| Doctor Panel | Repair queue | severity groups, cause, action, affected nodes |
| Settings | Permissions, appearance, and rules | Keychain access, system appearance mode, scan paths, ignored sources |

## Component Contracts

| Component | Contract |
| --- | --- |
| State chip | Uses the canonical state label and risk color. |
| Source badge | Names the source kind without exposing secret values. |
| Graph edge row | Shows relationship, origin, and confidence. |
| Doctor issue row | Shows severity, state, cause, and action. |
| Search field | Filters graph projections, not separate ad hoc lists. |
| Register button | Creates metadata for an existing secret store item. |

## Liquid Glass Rules

- Use Liquid Glass for the functional layer: sidebar, toolbar controls, popovers,
  floating repair rail, and command surfaces.
- Apple Music for Mac is the local reference for layered glass: translucent sidebar,
  floating command clusters, grouped library rows, selected-pill states, and bottom glass rails.
- Settings uses a material header plus grouped list sections; repeated rows stay plain
  and editable.
- Native glass buttons use `.glass` or `.glassProminent` when available, with system
  button styles on older macOS versions.
- Inventory cards are content-layer surfaces. On macOS 26+, the card shell and state
  poster use native `glassEffect`; older macOS versions fall back to material and
  low-alpha fills.
- The repair queue uses a full-width floating glass rail instead of a hard split panel.
- Do not use heavy Liquid Glass for repeated table cells or dense detail sections.
  Repeated credential cards may use low-tint native glass shells.
- Avoid stacked or nested glass. Group related controls into one glass surface instead.
- Do not hide text contrast behind material effects.
- Keep risk colors outside decorative materials when legibility would suffer.

## System Appearance

- The app follows system appearance only (Light/Dark) and stays within system contrast settings.
- Colors are semantically driven by state; risk semantics never depend on decorative accents.
- Settings can select display mode but cannot enable custom app color schemes.
- Avoid decorative gradients, orbs, and glow-only hierarchy.

## Interaction Rules

- Double-click opens the inspector, not a copy-secret action.
- `where` in the CLI maps to the same relationship detail as the inspector.
- Search narrows the graph by service, account, source path, tag, and state.
- Doctor actions must be reversible or explicit before they alter metadata.
- Empty states name what is absent and the next scan or register action.

## Accessibility Rules

- Risk is conveyed by label and icon, not color alone.
- Every icon-only button has an accessibility label and tooltip.
- Table rows remain readable under increased contrast and larger text.
- Keyboard navigation covers sidebar, table, inspector, and doctor panel.
