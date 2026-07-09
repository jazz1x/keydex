# Keydex Handoff - 2026-07-09

## BLUF

Keydex `main` is clean at `2bb7822` after PR #185. The automatic product,
screen, security, CI, and evidence-status gates are current. Do not mark the
overall goal complete yet: manual accessibility evidence is still pending, and
Developer ID signing readiness is blocked by a missing local Developer ID
Application identity.

## Current Repository State

| Item | Value |
| --- | --- |
| Repository | `/Users/jongyun/Documents/Codex/keydex` |
| Current main SHA | `2bb7822` |
| Current main commit | `test(app): add keychain prompt evidence (#185)` |
| Working tree after merge | Clean |
| Remote PR state | #185 merged |
| Main CI observed | `guard` success, `security` success on `2bb7822` |

## Recent Completed Slices

| PR | Main SHA | Result |
| --- | --- | --- |
| #183 | `6775818` | App Local refresh prompts before live Keychain reference scan. |
| #184 | `4964796` | Runtime Keychain prompt policy split into tested app policy. |
| #185 | `2bb7822` | Added runtime `keychain-prompt` screen and AX evidence scenario. |

## Evidence Status On `2bb7822`

```text
git_sha=2bb7822
git_dirty=clean
app_screen_evidence=pass
app_accessibility_manual=pending
app_accessibility_manual_pending_scenarios=14
app_accessibility_manual_pending_fields=56
release_signing_readiness=blocked
release_signing_readiness_developer_id_identity=missing
release_signing_readiness_notarytool=present
release_signing_readiness_stapler=present
release_signing_evidence=blocked
needs_attention=0
evidence status current
```

## Verification Already Run

| Gate | Result |
| --- | --- |
| `gitleaks protect --staged --redact` | Pass before #185 commit. |
| `pre-commit run --all-files` | Pass before #185 commit. |
| Commit hook | Pass; Swift 59 tests and `swift build --product KeydexApp`. |
| `make app-screen-evidence-all` | Pass on feature branch and again on `main`. |
| `make app-screen-evidence-review` | Pass on feature branch and again on `main`. |
| `make app-accessibility-smoke` | Pass; `keychain-prompt` expected 4, hidden 0. |
| `make evidence-status` | Current on `main` with expected pending/blocked states. |
| GitHub PR #185 CI | `guard`, `quality`, `release-smoke`, `gitleaks`, `trivy` pass. |
| GitHub main CI | `guard`, `security` pass on `2bb7822`. |

## Product State

| Area | State |
| --- | --- |
| Inventory graph | Env, shell, config, and Keychain observations feed graph-derived inventory. |
| CLI | Metadata-backed `scan`, `list`, `where`, and `doctor` are guarded by tests and docs. |
| Mac app | Native SwiftUI shell has card default, sidebar, inspector, settings, doctor, screen evidence, and AX smoke. |
| Secret boundary | Keydex stores references and observations, not secret values. Live Keychain scan is prompted before reference scan. |
| Release | Local release smoke and ad-hoc artifacts exist; trusted public distribution is not ready without Developer ID signing. |

## Known Open Blockers

### Manual Accessibility Evidence

- State: `pending`
- Scope: 14 scenarios, 56 fields
- Required fields per scenario: VoiceOver, keyboard traversal, state-not-color-only, dynamic type
- Rule: do not convert to `pass` without actual manual review evidence in `tmp/accessibility-evidence`

### Developer ID Signing

- State: `blocked`
- Missing: local `Developer ID Application` signing identity in Keychain
- Present: `notarytool`, `stapler`
- Rule: release signing evidence remains blocked until readiness passes

## Next Best Work

| Priority | Slice | Why |
| --- | --- | --- |
| P0 | Manual accessibility review session | This is the only remaining M4 pass gate that is not automatically satisfiable. |
| P0 | Developer ID identity setup | This is the only remaining M5 trusted distribution blocker. |
| P1 | UX polish evidence pass | Re-run Apple Music/Liquid Glass comparison after any visual changes and keep screen evidence current. |
| P1 | Icon and app chrome packaging check | Verify Dock icon, menu bar icon, and dashboard/launcher behavior against the selected pixel keyring direction. |
| P2 | Release candidate wording refresh | Update release notes only after accessibility/signing state changes, not before. |

## Resume Commands

```bash
cd /Users/jongyun/Documents/Codex/keydex
git status --short --branch
make evidence-status
make app-screen-evidence-all
make app-screen-evidence-review
make app-accessibility-smoke
```

For pending accessibility files:

```bash
make app-accessibility-evidence-template ARGS=--refresh-pending
make app-accessibility-evidence-status
```

For signing readiness:

```bash
make release-signing-readiness
make release-signing-evidence-template ARGS=--refresh-pending
```

## Workflow Guardrails

- Never push directly to `main`, `master`, or `release/*`.
- Use one feature branch and one PR per logical slice.
- Do not skip pre-commit hooks.
- Squash merge only after CI is green.
- Keep `make evidence-status` explicit: automatic gates can pass while manual and external gates remain pending or blocked.
- Use `rg` for content search, `fd` for file discovery, and `apply_patch` for manual edits.
