# Security

Keydex should not store secret values in repository files or metadata.

## Security Model

- Secret values belong in macOS Keychain or another explicit secret store.
- Keydex stores references, metadata, source observations, and doctor findings.
- Plaintext fallbacks are not silently accepted. They are surfaced as state.

## Reporting

Do not open public issues with secret values, tokens, screenshots of credentials, or local
paths that reveal sensitive environments. Use a private channel until the project has a
published disclosure process.

## Gates

- `make guard`: Swift format, tests, forbidden pattern scan.
- `make quality`: CLI/docs/state drift scan.
- CI: guard, quality, gitleaks, and Trivy.
