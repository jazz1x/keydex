# CLI Interface

Keydex CLI output follows the oh-my-borory operating-tool contract: short status
symbols first, scoped detail rails second, and color only when stdout is an interactive
terminal.

## Symbols

| Symbol | Meaning | Tone |
| --- | --- | --- |
| `◇` | command step, informational, empty, or no-op state | cyan |
| `✓` | clean or registered state | green |
| `⚠` | warning state that needs attention | yellow |
| `■` | error, expired, or missing state | red |
| `│` | scoped detail rail | dim grey |

## Scope Labels

| Label | Meaning |
| --- | --- |
| `[graph]` | graph-derived count or projection detail |
| `[keychain]` | macOS Keychain reference |
| `[env]` | environment variable reference |
| `[shell]` | shell profile reference |
| `[config]` | config file reference |

## Color Rules

- ANSI color is enabled only when stdout is a TTY.
- `NO_COLOR` disables ANSI color.
- `TERM=dumb` disables ANSI color.
- Scripts and CI should still see the same symbols, but no ANSI escape sequences.

## Output Shapes

```text
■ aws/jongyun  expired  1 sources
⚠ openai/jongyun: plaintext-fallback
│  [env] OPENAI_API_KEY
⚠ warning: openai/jongyun plaintext-fallback
│  cause: credential can still be resolved from plaintext configuration
│  action: migrate the value to Keychain and remove the plaintext fallback
◇  keydex scan config: 2 credential hints
│  [graph] sources 1 · edges 4
```
