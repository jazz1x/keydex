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

Run the project-contract gate when changing goals, planning, design, graph workflow, or
verification:

```bash
make contract
```

Run the loop-contract gate when changing module boundaries, UI/framework imports, or
the evidence loop:

```bash
make loop-contract
```

`make guard` is stack-free. It runs Swift formatting, tests, app build, and forbidden pattern scans.
`make quality` checks user-facing drift: CLI command inventory, state taxonomy docs, guard
documentation, anti-goals, workflow wiring, project contract, loop contract, CLI smoke,
app accessibility/design/UX flow contracts, and the menubar smoke script contract.

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
- [PRODUCT-PLAN.md](docs/PRODUCT-PLAN.md)
- [FEATURE-SPEC.md](docs/FEATURE-SPEC.md)
- [SWIFT-STYLE.md](docs/SWIFT-STYLE.md)
- [DESIGN-FOUNDATION.md](docs/DESIGN-FOUNDATION.md)
- [DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md)
- [GRAPH-WORKFLOW.md](docs/GRAPH-WORKFLOW.md)
- [LOOP-CONTRACT.md](docs/LOOP-CONTRACT.md)
- [ENFORCEMENT.md](docs/ENFORCEMENT.md)
- [VERIFICATION.md](docs/VERIFICATION.md)
- [VALIDATION-SCENARIOS.md](docs/VALIDATION-SCENARIOS.md)
- [SCREEN-VALIDATION.md](docs/SCREEN-VALIDATION.md)
- [RELEASE-READINESS.md](docs/RELEASE-READINESS.md)
- [TESTING-STRATEGY.md](docs/TESTING-STRATEGY.md)
