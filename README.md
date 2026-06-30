# Keydex

Mac developer credential inventory.

> Credentials should tell the truth about where they live.

Keydex is a Swift macOS utility and CLI for tracking developer credentials across
Keychain, shell profiles, environment variables, and local config files. It does not try
to become a password manager. Secret values stay in macOS Keychain or another explicit
secret store; Keydex stores references, metadata, graph edges, and doctor findings.

## Status

CLI workflows now cover env, shell, config file, and Keychain discovery with metadata-backed list/where/doctor flows.

## Commands

```bash
keydex list
keydex list --metadata ./metadata.json
keydex where openai
keydex where openai --metadata ./metadata.json
keydex doctor
keydex doctor --metadata ./metadata.json
keydex scan env
keydex scan shell
keydex scan config --path ./credentials.env
keydex scan keychain
keydex list --metadata ./metadata.json --include-keychain
keydex where openai --metadata ./metadata.json --include-keychain
keydex doctor --metadata ./metadata.json --include-keychain
```

When `--include-keychain` is used, Keydex reconciles metadata against live Keychain references:

- matched metadata-keychain pairs become `registered`
- missing metadata references become `missing-keychain-item`
- unmatched live Keychain references become `orphan`

## Guard

```bash
make guard
make quality
make contract
```

## Philosophy

- [PHILOSOPHY.md](docs/PHILOSOPHY.md)
- [GOALS.md](docs/GOALS.md)
- [PRODUCT-PLAN.md](docs/PRODUCT-PLAN.md)
- [FEATURE-SPEC.md](docs/FEATURE-SPEC.md)
- [SWIFT-STYLE.md](docs/SWIFT-STYLE.md)
- [DESIGN-FOUNDATION.md](docs/DESIGN-FOUNDATION.md)
- [DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md)
- [GRAPH-WORKFLOW.md](docs/GRAPH-WORKFLOW.md)
- [ENFORCEMENT.md](docs/ENFORCEMENT.md)
- [VERIFICATION.md](docs/VERIFICATION.md)
- [VALIDATION-SCENARIOS.md](docs/VALIDATION-SCENARIOS.md)
- [SCREEN-VALIDATION.md](docs/SCREEN-VALIDATION.md)
- [RELEASE-READINESS.md](docs/RELEASE-READINESS.md)
- [TESTING-STRATEGY.md](docs/TESTING-STRATEGY.md)
