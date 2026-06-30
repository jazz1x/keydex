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

Run the project-contract gate when changing goals, design, graph workflow, or verification:

```bash
make contract
```

`make guard` is stack-free. It runs Swift formatting, tests, and forbidden pattern scans.
`make quality` checks user-facing drift: CLI command inventory, state taxonomy docs, guard
documentation, anti-goals, workflow wiring, and the project contract.

## Branch And PR Workflow

- Do not push directly to `main`.
- Create a feature branch and open a pull request.
- Use squash merge only.
- Do not bypass pre-commit hooks. If a hook fails, fix the root cause.
- Keep changes focused. Add structure only when it protects a real invariant.
- Treat UI, CLI, and doctor screens as graph projections.

## Design Philosophy

Read these before non-trivial changes:

- [PHILOSOPHY.md](docs/PHILOSOPHY.md)
- [GOALS.md](docs/GOALS.md)
- [SWIFT-STYLE.md](docs/SWIFT-STYLE.md)
- [DESIGN-FOUNDATION.md](docs/DESIGN-FOUNDATION.md)
- [DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md)
- [GRAPH-WORKFLOW.md](docs/GRAPH-WORKFLOW.md)
- [ENFORCEMENT.md](docs/ENFORCEMENT.md)
- [VERIFICATION.md](docs/VERIFICATION.md)
