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
| `surface.sidebar` | Liquid Glass material | navigation and scope filters |
| `surface.inspector` | Liquid Glass material | selected item detail |
| `text.primary` | label | credential names and actions |
| `text.secondary` | secondary label | metadata and source paths |
| `risk.info` | blue | neutral findings |
| `risk.warning` | orange | plaintext, orphan, expiring, duplicate |
| `risk.error` | red | missing keychain item, expired |
| `spacing.row` | 8 px | table row vertical rhythm |
| `spacing.panel` | 16 px | inspector and popover padding |
| `radius.control` | system default | buttons, fields, segmented controls |
| `radius.card` | 8 px max | repeated issue rows only |

## App Surfaces

| Surface | Role | Required Controls |
| --- | --- | --- |
| Sidebar | Scope navigation | All, Expiring, Plaintext, Orphans, Duplicates, Services, Tags |
| Toolbar | Global actions | search, scan, register, doctor, settings |
| Inventory Table | Primary working view | sortable columns, state chips, source count, last observed |
| Inspector | Relationship detail | credential, sources, graph edges, expiry, notes, actions |
| Doctor Panel | Repair queue | severity groups, cause, action, affected nodes |
| Settings | Permissions and rules | Keychain access, scan paths, ignored sources |

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

- Use Liquid Glass for hierarchy: sidebar, toolbar, inspector, popovers, and command
  surfaces.
- Settings uses a material header plus grouped list sections; repeated rows stay plain
  and editable.
- Do not use Liquid Glass for repeated table cells.
- Do not hide text contrast behind material effects.
- Keep risk colors outside decorative materials when legibility would suffer.

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
