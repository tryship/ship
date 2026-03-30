# Ship for Codex

Ship workflow skills run natively in OpenAI Codex CLI via skill discovery.

## Quick install

Tell Codex:

> Fetch and follow instructions from https://raw.githubusercontent.com/tryship/ship/refs/heads/main/.codex/INSTALL.md

Or install manually — see [`.codex/INSTALL.md`](../.codex/INSTALL.md).

## What works in Codex

### Full support

- **Workflow skills** — `auto`, `plan`, `implement`, `debug`, `refactor`, `review`, `test`, `clean`, `qa`, `handoff`, `setup`
- **AGENTS.md** — Ship-generated AGENTS.md is consumed natively by Codex
- **Skill discovery** — Codex finds Ship skills automatically after symlink

### Partial support

- **Adversarial planning** (`plan` skill) — Uses Codex MCP in Claude Code for independent challenge. In Codex CLI, falls back to spawned worker agent or self-review.
- **Subagent dispatch** — Claude Code named agents map to generic `spawn_agent`. See [`codex-tools.md`](./codex-tools.md) for translation table.

### Not supported (requires CI backstop)

- **Policy enforcement** — Ship's always-on boundary/secrets/operations hooks depend on Claude Code's per-tool hook events (`PreToolUse Write|Edit|Read`). Codex hooks only intercept Bash today.
- **Audit trail** — Ship's audit logger depends on `PostToolUse` and `SessionEnd` events not available in Codex.
- **Policy self-protection** — Cannot prevent policy file modification via Codex hooks alone.

## Recommended setup for teams

For teams using Ship on Codex, compensate for missing enforcement with:

1. **CI gate** — Add Ship policy verification to your CI pipeline (see TODO.md P0)
2. **Git hooks** — Pre-commit hooks for secrets scanning and test requirements
3. **PR review** — Use Ship's `review` skill before merging

