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
| `surface.sidebar` | native sidebar visual effect + background extension + milky wash | sidebar slab, navigation, and scope filters |
| `glass.sidebar.wash` | light: warm white 0.86 alpha; dark: white 0.08 alpha | Apple Music-like sidebar milky wash |
| `surface.inspector` | native Liquid Glass, 8 px radius | selected item detail |
| `surface.card` | poster-only native Liquid Glass, 8 px radius | inventory card artwork and grouped settings only |
| `glass.sidebar.selection` | primary 0.045 alpha | selected sidebar rows |
| `glass.content.tint` | white 0.07 alpha | card and inspector glass shell tint |
| `glass.control.tint` | white 0.12 alpha | toolbar mode cluster tint |
| `glass.poster.tint` | semantic state color 0.22 alpha | card poster glass tint |
| `glass.floating.tint` | white 0.20 alpha | reserved bottom repair rail tint |
| `artwork.state.tint` | semantic state color 0.22 alpha | card poster color field |
| `artwork.poster.symbol` | 50 pt size + 0.50 alpha | subdued credential glyph inside poster |
| `artwork.poster.wash` | semantic state color 0.04 alpha + white 0.08 highlight | Apple Music-like poster media wash |
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
| Toolbar | Global actions | glass mode cluster, register, settings |
| Inventory Table | Primary working view | grouped list rows, selected pill, sortable columns, state chips, source count, last observed |
| Inventory Cards | Secondary scan view | poster-style credential artwork, one compact metadata caption, source count affordance |
| Inspector | Relationship detail | credential, sources, graph edges, expiry, notes, actions |
| Doctor Panel | Repair queue | reserved music-player-like footer rail with severity, cause, action, and count controls |
| Settings | Permissions, appearance, and rules | Keychain access, system appearance mode, scan paths, ignored sources |

## Component Contracts

| Component | Contract |
| --- | --- |
| State chip | Uses the canonical state label and risk color. |
| Source badge | Names the source kind without exposing secret values. |
| Graph edge row | Shows relationship, origin, and confidence. |
| Doctor issue row | Shows severity, state, cause, and action. |
| Search field | Plain sidebar search row; filters graph projections, not separate ad hoc lists. |
| Register button | Creates metadata for an existing secret store item. |

## Liquid Glass Rules

- Use Liquid Glass for the functional layer: sidebar slab, toolbar controls, popovers,
  reserved footer repair rail, and command surfaces.
- Apple Music for Mac is the local reference for layered glass: translucent sidebar,
  floating command clusters, grouped library rows, selected-pill states, and bottom glass rails.
- Sidebar glass uses the native macOS sidebar visual effect, then extends behind the
  hidden titlebar, with a subtle warm milky wash so the slab reads like Music's
  full-height navigation rail instead of a gray app panel.
- Sidebar scroll content hides its own background so the native sidebar material,
  not a default scroll fill, is the visible surface.
- Sidebar wash is layered above the native material and below row content, preserving
  text contrast while matching Music's warm translucent slab.
- Sidebar content also owns the wash layer because macOS scroll containers can draw
  their own neutral background above the split-view material.
- Sidebar search is not a nested glass card. It is a plain search row on the sidebar
  material, matching Music's Library and Playlist navigation.
- Toolbar mode controls stay in one glass cluster instead of separate floating islands.
- Settings uses a material header plus grouped list sections; repeated rows stay plain
  and editable.
- Native glass buttons use `.glass` or `.glassProminent` when available, with system
  button styles on older macOS versions.
- Inventory cards are content-layer tiles. On macOS 26+, only the credential poster
  uses native `glassEffect`; older macOS versions fall back to material and low-alpha fills.
- Card mode follows Music's Library and Playlist tile hierarchy: poster/artwork first,
  primary title inside the poster surface, and one compact metadata caption below.
- Card mode uses a two-column Music-like library surface: sidebar plus flowing card
  content. The persistent inspector stays in list mode, where dense operational
  review is the primary task.
- Card grids use adaptive bounded columns so wider card-mode content forms a Music
  shelf of artwork tiles instead of stretching into dashboard banners.
- Repeated inventory cards have no second outer card shell. Selection belongs on
  the poster outline so the artwork remains the only framed tile.
- Repeated inventory cards follow a single poster frame only contract. Card mode
  has no repeated capsule badge strip below each poster; state,
  Keychain, and source detail compress into one plain caption.
- Poster surfaces may use semantic state-color media wash. They must not use decorative
  graph lines, constellations, glow-only hierarchy, or fake analytics imagery.
- Poster glyphs stay subdued so the credential card reads like Music library artwork,
  not a dashboard status tile.
- The repair queue uses a centered music-player-like repair rail inside a
  reserved footer rail instead of a hard split panel or overlay. Scrollable
  content must end above the rail so rows and playlist-style cards are never occluded.
- Do not use heavy Liquid Glass for repeated table cells or dense detail sections.
  Repeated credential posters may use low-tint native glass; the card shell stays unframed.
- Repeated state and metadata chips use flat semantic fills and strokes, not material
  capsules, so table/card density stays closer to Music library rows.
- Source metadata uses list/document symbols, never connected-dot graph glyphs.
- User-facing app copy describes inventory, Keychain links, states, and sources.
  It does not expose graph-derived implementation language in empty states.
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
