# AGENTS.md

## Commands

| Action | Command |
|--------|---------|
| Validate JSON | `jq . <file>` |
| Lint shell | `shellcheck scripts/*.sh` (if installed) |
| Test hooks | `echo '<json>' \| bash scripts/<hook>.sh` |
| Reload plugin | `/reload-plugins` in Claude Code |

## Repository Map

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `scripts/` | Shell scripts | Workflow hooks (stop-gate) and utilities (task-id, check-conventions) |
| `hooks/` | `hooks.json` | Plugin-level hook registration (Stop only) |
| `skills/` | Skill dirs | Claude Code slash commands (/ship:auto, /ship:plan, etc.) |
| `skills/setup/` | Setup skill | Infra bootstrap + convention discovery, AGENTS.md + CONVENTIONS.md generation |
| `.claude-plugin/` | `plugin.json` | Plugin metadata for ShipAI |
| `.mcp.json` | MCP config | Codex MCP server registration |

## Architecture

Two independent layers:

**Harness layer (opt-in via /ship:setup):** AI analyzes the project and generates enforceable conventions.
- Generates `AGENTS.md` (prevention — AI reads at session start)
- Generates `.ship/rules/CONVENTIONS.md` (enforcement — checked on every Write/Edit)
- Enforcement via command hook: `scripts/check-conventions.sh` calls `claude -p` (Haiku) to judge code against CONVENTIONS.md

**Workflow layer (opt-in via /ship:auto):** Fires only during ship-coding sessions.
- `stop-gate.sh` — blocks session exit until all pipeline artifacts are complete

## Code Style

- Shell: `set -u` at top of every script, `local` for function variables
- JSON parsing: `jq` only (no yq, no Python yaml)
- Hook input: always `INPUT=$(cat)` then extract fields with `jq -r`
- Hook output: `jq -n` to produce response JSON
- Use Conventional Commits: `feat(harness):`, `fix(harness):`, `feat(plugin):`

## Boundaries

### Always Do
- Use `set -u` in every new shell script
- Exit 0 silently when config files don't exist (graceful degradation)
- Use Conventional Commits
- Test hooks by piping JSON stdin: `echo '{"cwd":"/path","tool_name":"Edit",...}' | bash scripts/hook.sh`

### Never Do
- Use `eval` on config values (use `bash -c` instead)
- Use `\s` in `grep -E` (not POSIX on macOS; use `[[:space:]]`)
- Depend on `yq` or PyYAML (JSON-only, parsed with `jq`)

## Gotchas

- macOS `/tmp` resolves to `/private/tmp` via symlink. `git rev-parse --show-toplevel` returns the resolved path. All path matching must handle both forms.
- Plugin-level hooks fire for ALL sessions. Project-level hooks (in `.claude/settings.json`) fire only for that project.
- Hook handlers run in parallel when multiple match the same event. Hooks must not depend on execution order.
- `stop-gate.sh` checks `stop_hook_active` to prevent infinite loops. If it blocked once, it lets go on retry.
