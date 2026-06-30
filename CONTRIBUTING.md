# Contributing to Keydex

Keydex is a personal macOS developer credential inventory. The project follows the same
discipline as the rest of the Galmuri-style tools: small changes, explicit state, and
guards before claims.

## Build And Test

Run the structural gate before committing:

```bash
make guard
```

Run the release-quality drift gate before opening a PR:

```bash
make quality
```

`make guard` is stack-free. It runs Swift formatting, tests, and forbidden pattern scans.
`make quality` checks user-facing drift: CLI command inventory, state taxonomy docs, guard
documentation, anti-goals, and workflow wiring.

## Branch And PR Workflow

- Do not push directly to `main`.
- Create a feature branch and open a pull request.
- Use squash merge only.
- Do not bypass pre-commit hooks. If a hook fails, fix the root cause.
- Keep changes focused. Add structure only when it protects a real invariant.

## Design Philosophy

Read these before non-trivial changes:

- [PHILOSOPHY.md](docs/PHILOSOPHY.md)
- [SWIFT-STYLE.md](docs/SWIFT-STYLE.md)
- [DESIGN-FOUNDATION.md](docs/DESIGN-FOUNDATION.md)
- [ENFORCEMENT.md](docs/ENFORCEMENT.md)
