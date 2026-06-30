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
| State enum labels stay stable | unit tests |
| CLI command docs drift | `make quality` |
| State taxonomy docs drift | `make quality` |
| Secret value stays outside metadata | review plus forbidden scan |
| UI does not invent state | review |
| Liquid Glass remains hierarchical | review |

## Local Gate

Run:

```bash
make guard
make quality
```

The pre-commit hook runs the same command.

## CI Gate

The GitHub Actions jobs are named `guard`, `quality`, `gitleaks`, and `trivy`.
The `main` branch protection should require all four when GitHub plan settings allow it.

## Review Checklist

- Does any state name overclaim reality?
- Does any fallback happen silently?
- Does any metadata field store a secret value?
- Did external input get parsed once at the boundary?
- Is this abstraction carrying an invariant, or just carrying anxiety?
