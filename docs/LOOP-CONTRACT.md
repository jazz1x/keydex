# Loop Contract

Keydex improves through a closed loop: name the intent, protect the architecture,
change the smallest owned surface, and leave evidence that the result is truer than
before.

## Loop

1. **Intent** - Tie the change to a goal, screen scenario, CLI contract, or release
   gate before editing.
2. **Boundary** - Keep domain rules in `KeydexCore`; keep macOS Security access in
   `KeydexKeychain`; keep file parsing in `KeydexSources` and `KeydexStore`; keep
   shared local graph orchestration in `KeydexRuntime`; keep SwiftUI/AppKit composition
   in `KeydexApp`.
3. **Implementation** - Prefer parse-don't-validate, explicit result states, and
   graph projections over defensive fallbacks or hidden branching.
4. **Evidence** - Run the narrowest command that proves the change, then run the
   wider gate before review or release.
5. **Reflection** - If a failure required a new guardrail, encode that guardrail in
   docs, tests, scripts, or UI evidence before closing the loop.
   New automation must replace a repeated, observable failure that existing gates cannot
   express; otherwise update the existing contract or leave a manual review note.

## Architecture Boundaries

| Layer | Owns | May depend on | Must not import |
| --- | --- | --- | --- |
| `KeydexCore` | Domain values, graph, doctor, reminders | Foundation | SwiftUI, AppKit, Security |
| `KeydexKeychain` | macOS Keychain inventory adapter | KeydexCore, Security | SwiftUI, AppKit |
| `KeydexSources` | Environment, shell, config observations | KeydexCore, Foundation | SwiftUI, AppKit, Security |
| `KeydexStore` | Metadata parsing and persistence | KeydexCore, Foundation | SwiftUI, AppKit, Security |
| `KeydexRuntime` | Local graph build orchestration | KeydexCore, KeydexSources, KeydexStore, Foundation | SwiftUI, AppKit, Security, KeydexKeychain |
| `KeydexMacRuntime` | macOS runtime source adapters | KeydexRuntime, KeydexKeychain, Foundation | SwiftUI, AppKit, Security |
| `keydex` | CLI orchestration and terminal presentation | Core, sources, store, keychain | SwiftUI, AppKit |
| `KeydexApp` | Native macOS presentation and screen evidence hooks | KeydexCore, KeydexRuntime, KeydexMacRuntime, SwiftUI, AppKit | Security |

Source imports follow the package dependency direction. `KeydexApp` consumes
`KeydexCore` projections, `KeydexRuntime` local graph orchestration,
`KeydexMacRuntime` live macOS source adapters, and local presentation state; it
must not import `KeydexKeychain`, `KeydexSources`, or `KeydexStore` directly.
Qualified imports such as `import struct KeydexStore.MetadataRecord` count as direct
imports.
`make loop-contract` also parses `swift package dump-package` output so the
actual SwiftPM target dependency graph must match these boundaries, not just the
source import text.

## Clean-Code Rules

- State names are product vocabulary. Adding or changing one requires docs, CLI,
  design, tests, and screen evidence updates.
- The graph is the single integration shape. UI and CLI consume projections rather
  than re-deriving credential truth.
- A fallback must be visible as state, finding, or evidence. Silent fallbacks are
  product bugs.
- App bootstrap helpers for icons and window presets live outside the shell view
  file so app lifecycle wiring stays separate from inventory composition.
- App design tokens, Liquid Glass modifiers, and layout constants live outside the
  shell view file so UI composition can evolve without hiding presentation contracts.
- App presentation rows, preview scenarios, and checked-in sample data live outside
  the shell view file so the shell remains orchestration, not a model bucket.
- Inventory content, cards, tables, and inspector support views live outside the
  shell view file so graph projection display stays separate from app orchestration.
- Doctor repair rail presentation lives outside the shell view file so graph health
  feedback stays a focused reusable surface.
- Sidebar, toolbar, and rail support views live outside the shell view file so
  navigation composition can evolve without making the shell a component bucket.
- Settings panels and rows live outside the shell view file so preferences remain
  editable presentation state, not orchestration code.
- App persistence helpers use their own boundary IDs. Stores must not depend on
  presentation row types such as `CredentialRow`.
- The shell view file keeps only app entry and inventory orchestration. Reusable
  bootstrap, design, presentation, inventory, doctor, sidebar, and settings surfaces
  stay in their owned files.
- A boundary exception needs an explicit root-cause note in the PR and a follow-up
  guardrail when the exception would otherwise repeat.
- A guardrail that needs its own mini-framework is suspect until the repeated failure is
  proven. Prefer one narrow contract line over a new harness.

## Verification Ladder

| Change type | Minimum evidence | Wider gate |
| --- | --- | --- |
| Domain or graph | `swift test` | `make guard` |
| CLI behavior | `make cli-smoke` | `make quality` |
| Mac app UI | `make app-design-contract` plus relevant screen evidence | `make quality` |
| Architecture boundary | `make loop-contract` | `make quality` |
| Release packaging | `make release-smoke` | CI `release-smoke` |

## Completion Rule

No loop is complete because the code "looks right." It is complete only when the
contract, implementation, and evidence all point to the same current Git state.
