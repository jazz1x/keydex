# Enforcement

Keydex uses three enforcement layers.

1. Mechanical: Swift compiler, `swift-format`, tests, forbidden-pattern scan.
2. Gate: pre-commit hook and CI run `make guard`.
3. Review: the design question "does this state lie?"

## Rule Mapping

| Rule | Enforced By |
| --- | --- |
| Formatting | `swift-format lint --strict` |
| Tests | `swift test` |
| No silent `try?` | `scripts/forbidden-patterns.sh` |
| No empty `catch` | `scripts/forbidden-patterns.sh` |
| No obvious secret-value columns | `scripts/forbidden-patterns.sh` |
| Clean Architecture boundaries | `scripts/loop-contract.sh` |
| State enum labels stay stable | unit tests |
| CLI command docs drift | `make quality` |
| State taxonomy docs drift | `make quality` |
| Secret value stays outside metadata | review plus forbidden scan |
| Project Contract docs stay present | `scripts/project-contract.sh` |
| Evidence manifests match current SHA and dirty state | evidence review scripts |
| Evidence status stays explicit | `make evidence-status` distinguishes `pass`, `pending`, `blocked`, and `needs-attention` without turning manual blockers into false passes. |
| Planning pack stays present | `scripts/project-contract.sh` |
| Graph workflow stays visible | `scripts/project-contract.sh` |
| UI does not invent state | review |
| Liquid Glass remains hierarchical | review |

## Local Gate

Run:

```bash
make guard
make quality
```

The pre-commit hook runs `keydex-guard` for code/build paths and `keydex-quality` for docs, scripts, and workflow paths.

## CI Gate

The GitHub Actions jobs are named `guard`, `quality`, `release-smoke`, `gitleaks`, and
`trivy`. The `main` Branch Protection requires all five.

## Review Checklist

- Does any state name overclaim reality?
- Does any fallback happen silently?
- Does any metadata field store a secret value?
- Did external input get parsed once at the boundary?
- Is this abstraction carrying an invariant, or just carrying anxiety?
- Is the view or command a graph projection rather than a second source of truth?
- Did the change keep framework imports inside the layer that owns them?
- Is the work covered by product plan, feature spec, and validation scenarios?
