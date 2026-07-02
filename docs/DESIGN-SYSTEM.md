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
| `surface.sidebar` | native sidebar visual effect + background extension; no color wash overlay | sidebar slab, navigation, and scope filters |
| `glass.sidebar.wash` | none; native `.sidebar` material owns the visual effect | Apple Music-like sidebar glass without painted wash |
| `surface.inspector` | native Liquid Glass, 8 px radius | selected item detail |
| `surface.card` | poster-only native Liquid Glass, 8 px radius | inventory card artwork and grouped settings only |
| `glass.sidebar.selection` | primary 0.045 alpha | selected sidebar rows |
| `glass.content.tint` | white 0.035 alpha | card and inspector glass shell tint |
| `glass.control.tint` | white 0.055 alpha | toolbar mode cluster tint |
| `glass.poster.tint` | semantic state color 0.18 alpha | card poster glass tint |
| `glass.floating.refraction` | native clear interactive glass + materialize transition; no tint path | centered Doctor rail surface |
| `surface.footerRail` | transparent footer lane + 90 pt content reserve + top separator 0.08 alpha | Apple Music-like footer rail and bottom player lane |
| `artwork.state.tint` | semantic state color 0.18 alpha | card poster color field |
| `artwork.custom.override` | local image copied under Application Support/Keydex/Artwork with preset fallback | user-owned card artwork |
| `artwork.poster.symbol` | 50 pt size + 0.50 alpha | subdued credential glyph inside poster |
| `artwork.poster.wash` | semantic state color 0.045 alpha + white 0.055 highlight | Apple Music-like poster media wash |
| `text.primary` | label | credential names and actions |
| `text.secondary` | secondary label | metadata and source paths |
| `risk.info` | blue | neutral findings |
| `risk.warning` | orange | plaintext, orphan, expiring, duplicate |
| `risk.error` | red | missing keychain item, expired |
| `spacing.row` | 8 px | table row vertical rhythm |
| `spacing.panel` | 16 px | inspector and popover padding |
| `layout.sidebar.search` | top 12 pt, row height 36 pt, horizontal inset 12 pt, body font | Apple Music-like sidebar search cadence |
| `layout.card.shelf` | top 18 pt, page-to-section 16 pt, section-to-grid 10 pt, row gap 14 pt | card-mode shelf rhythm |
| `layout.card.poster` | 248 pt height, 8 pt radius, poster-only artwork | repeated credential card artwork |
| `layout.card.textDeck` | poster-to-text 8 pt, title/caption gap 2 pt, 2 pt horizontal inset | credential title and caption below poster |
| `layout.footerRail.maxWidth` | 720 pt | Music-like centered bottom rail width |
| `motion.content` | snappy 0.24 s, extraBounce 0.04 | card/list/detail surface transitions |
| `motion.control` | snappy 0.18 s, extraBounce 0.08 | hover and small control feedback |
| `radius.control` | system default | buttons, fields, segmented controls |
| `radius.card` | 8 px max | repeated issue rows only |
| `appearance.mode` | system light/dark | no product-level custom palettes |

## App Surfaces

| Surface | Role | Required Controls |
| --- | --- | --- |
| Sidebar | Scope navigation | All, Expiring, Plaintext, Orphans, Duplicates, Services, Tags |
| Toolbar | Global actions | glass mode cluster, register, settings |
| App Icons | App and menu bar identity | bundled Keydex app icon, monochrome template menu bar icon |
| Inventory Table | Primary working view | grouped list rows, selected pill, sortable columns, state chips, user-owned tag metadata, source count, last observed |
| Inventory Cards | Secondary scan view | poster-only credential artwork, two-line title/caption deck below, source count affordance, Music-like detail page on click |
| Inspector | Relationship detail | credential, sources, graph edges, expiry, notes, actions |
| Doctor Panel | Repair queue | transparent music-player-like footer lane with centered clear glass rail, 90 pt content reserve, severity, cause, action, and count controls |
| Settings | Permissions, appearance, tags, and rules | in-window Liquid Glass overlay for Keychain access, system appearance mode, scan paths, user-owned tags, ignored sources |

## Component Contracts

| Component | Contract |
| --- | --- |
| State chip | Uses the canonical state label and risk color. |
| Source badge | Names the source kind without exposing secret values. |
| Tag chip | Shows user-owned tag metadata without changing graph-derived credential truth. |
| Graph edge row | Shows relationship, origin, and confidence. |
| Doctor issue row | Shows severity, state, cause, and action. |
| Search field | Plain sidebar search row; 12 pt top inset, 36 pt row height, 12 pt horizontal inset, body-sized icon/text, inline clear affordance when populated. |
| Register button | Creates metadata for an existing secret store item. |

## Liquid Glass Rules

- Use Liquid Glass for the functional layer: sidebar slab, toolbar controls, popovers,
  reserved footer repair rail, and command surfaces.
- Apple Music for Mac is the local reference for layered glass: translucent sidebar,
  floating command clusters, grouped library rows, selected-pill states, and bottom glass rails.
- Sidebar glass uses the native macOS sidebar visual effect, then extends behind the
  hidden titlebar. Do not paint a color wash over the material; the sidebar must
  read as a native glass slab, not a gray app panel.
- Sidebar and footer rail have no color wash overlay; native material and glass
  APIs own the translucency, blur, and refraction.
- Sidebar scroll content hides its own background so the native sidebar material,
  not a default scroll fill, is the visible surface.
- Sidebar content sits directly on native material. Scroll containers must not add
  their own neutral fill above the split-view material.
- Sidebar navigation preserves user scroll position; do not force-scroll the sidebar
  to the top on selection, mode, or detail changes.
- Sidebar search is not a nested glass card. It is a plain search row on the sidebar
  material, matching Music's Library and Playlist navigation.
- Toolbar mode controls stay in one glass cluster instead of separate floating islands.
- Settings uses a material header plus grouped list sections; repeated rows stay plain
  and editable. Tags are user-owned metadata managed beside sources, not graph truth.
- Settings outer overlay and header controls use native Liquid Glass on macOS 26+.
  Inner grouped rows stay plain low-alpha surfaces so nested cards do not flatten
  the sheet into an opaque gray panel.
- `.regularMaterial`, `.thinMaterial`, and `.ultraThinMaterial` are fallback-only
  paths for older macOS.
- Settings overlays must expose an icon-only close affordance in the header and bind
  Escape to the same dismiss action.
- Settings header status pills stay single-line; controls may compress surrounding
  spacing, but labels must not wrap.
- Settings toggle rows keep label copy left-aligned and place the switch control on
  the right edge of the row.
- Native glass buttons use `.glass` or `.glassProminent` when available, with system
  button styles on older macOS versions.
- Inventory cards are content-layer tiles. On macOS 26+, only the credential poster
  uses native `glassEffect`; older macOS versions fall back to material and low-alpha fills.
- Card mode follows Music's Library and Playlist tile hierarchy: poster/artwork first,
  then a two-line title/caption deck below the poster. The repeated poster itself
  carries no service/account/status text stack.
- Card mode uses Music-like content cadence: page title, section heading with
  chevron, then poster shelf.
- Card mode uses a two-column Music-like library surface: sidebar plus flowing card
  content. The persistent inspector stays in list mode, where dense operational
  review is the primary task.
- Card grids use adaptive bounded columns so wider card-mode content forms a Music
  shelf of artwork tiles instead of stretching into dashboard banners.
- Repeated inventory cards have no second outer card shell. Selection belongs on
  the poster outline so the artwork remains the only framed tile.
- Repeated card selection must not use the global blue accent ring. Selected posters
  use the artwork preset's own low-alpha stroke so mouse selection does not read as
  keyboard focus.
- Repeated card keyboard focus suppresses the default system focus effect and uses
  a neutral poster stroke. The card remains a keyboard-accessible button; only the
  blue ring is replaced.
- Repeated inventory cards follow a single poster frame only contract. Card mode
  has no repeated capsule badge strip below each poster; account, canonical state,
  and Keychain status compress into one plain caption below the title.
- Clicking an inventory card opens a Music-like credential detail page inside the
  content pane: back-to-library affordance, large poster artwork, compact action
  cluster, status chip, and source rows that read like a playlist track list. Card
  click detail must not reintroduce a persistent right inspector or modal sheet
  into card mode.
- Credential-scoped detail and inspector actions use neutral action buttons. The
  global toolbar registration command can stay prominent, but opening a credential
  must not make a scoped action look like a default focused blue control.
- Card-to-detail and detail-to-card transitions use the content motion token and
  restore the clicked card as the return anchor instead of resetting the shelf to
  the top.
- Poster surfaces may use semantic state-color media wash. They must not use decorative
  graph lines, constellations, glow-only hierarchy, or fake analytics imagery.
- Poster glyphs stay subdued so the credential card reads like Music library artwork,
  not a dashboard status tile.
- Custom artwork controls live beside credential identity actions in card detail and
  inspector surfaces. They must not be nested under tag management, and missing files
  fall back to the credential's default preset artwork.
- Custom artwork image resolution uses the Shell-owned artwork root, not a default
  store recreated inside the artwork view.
- The repair queue uses a centered music-player-like repair rail inside a
  transparent footer lane instead of a hard split panel or opaque painted overlay.
  The lane has a 0.08 alpha top separator, and scrollable content keeps a 90 pt
  reserve so rows and playlist-style cards are never occluded while the glass
  still has real content behind it.
- The floating repair rail uses native clear interactive glass with materialize
  transition and no tint path; do not simulate Liquid Glass by painting a clear
  or milky overlay on top. Clear glass is limited to the poster-backed bottom rail
  and explicitly dimmed settings sheet.
- Doctor rail feedback uses native SwiftUI feedback hooks: symbol bounce,
  numeric content transitions, macOS hover scale, and sensory feedback on state
  changes.
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
- Search results show a lightweight Music-like result header without creating a
  second nested search card.
- Doctor actions must be reversible or explicit before they alter metadata.
- Empty states name what is absent and the next scan or register action.

## Accessibility Rules

- Risk is conveyed by label and icon, not color alone.
- Every icon-only button has an accessibility label and tooltip.
- Table rows remain readable under increased contrast and larger text.
- Keyboard navigation covers sidebar, table, inspector, and doctor panel.
