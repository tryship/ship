# AGENTS.md

## Commands

| Action | Command |
|--------|---------|
| Validate JSON | `jq . <file>` |
| Lint shell | `shellcheck bin/*.sh bin/lib/*.sh` (if installed) |
| Test hooks | `echo '<json>' \| bash bin/<hook>.sh` |
| Reload plugin | `/reload-plugins` in Claude Code |

## Repository Map

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `bin/` | Shell scripts | Hook handlers (always-on policy + workflow gates) |
| `bin/lib/` | `policy.sh` | Shared library sourced by all policy hooks |
| `hooks/` | `hooks.json` | Plugin-level hook registration (SessionStart, PreToolUse, PostToolUse, Stop, SessionEnd) |
| `skills/` | 11 skill dirs | Claude Code slash commands (/ship:auto, /ship:plan, etc.) |
| `skills/setup/templates/` | Config templates | CI, Dependabot, labeler, default policy JSON |
| `.claude-plugin/` | `plugin.json` | Plugin metadata for Claude Code marketplace |

## Architecture

Two independent layers, both in `hooks/hooks.json`:

**Policy layer (always-on):** Fires on every Claude Code session, no opt-in needed.
- `policy-context.sh` — SessionStart: loads `.ship/ship.policy.json`, injects summary
- `policy-boundaries.sh` — PreToolUse: blocks Write/Edit/Read to protected paths
- `policy-secrets.sh` — PreToolUse: scans Write/Edit content for credential patterns
- `policy-operations.sh` — PreToolUse: blocks dangerous Bash commands, enforces dependency/git rules
- `audit-logger.sh` — PostToolUse + SessionEnd: structured JSON audit log

**Workflow layer (opt-in via /ship:auto):** Fires only during ship-coding sessions.
- `guard-orchestrator.sh` — blocks orchestrator from writing files (read-only enforcement)
- `stop-gate.sh` — blocks session exit until all pipeline artifacts are complete
- `post-compact.sh` — re-injects task state after context compaction

All policy hooks source `bin/lib/policy.sh` for shared functions (load_policy, match_glob, match_regex, get_action, log_audit).

## Code Style

- Shell: `set -u` at top of every script, `local` for function variables
- JSON parsing: `jq` only (no yq, no Python yaml)
- Hook input: always `INPUT=$(cat)` then extract fields with `jq -r`
- Hook output: `jq -n` to produce response JSON
- No subagent bypass in policy hooks (no `agent_id` check)
- Existing workflow hooks DO bypass subagents (check `agent_id`)
- Policy file: `.ship/ship.policy.json` (JSON, not YAML)
- Audit logs: `.ship/audit/YYYY-MM-DD.jsonl` (append-only)

## Boundaries

### Always Do
- Source `bin/lib/policy.sh` in every new hook handler
- Exit 0 silently when no policy file exists (graceful degradation)
- Use `_policy_repo_root` for path resolution (handles macOS symlinks)
- Use Conventional Commits: `feat(policy):`, `fix(policy):`, `feat(plugin):`
- Test hooks by piping JSON stdin: `echo '{"cwd":"/path","tool_name":"Edit",...}' | bash bin/hook.sh`

### Never Do
- Use `eval` on policy values (use `bash -c` instead)
- Use `\s` in `grep -E` (not POSIX on macOS; use `[[:space:]]`)
- Depend on `yq` or PyYAML (JSON-only, parsed with `jq`)
- Add `agent_id` bypass to policy hooks (they must fire for subagents too)
- Hardcode phase requirements in stop-gate (read from policy workflow.phases)

## Gotchas

- macOS `/tmp` resolves to `/private/tmp` via symlink. `git rev-parse --show-toplevel` returns the resolved path. All path matching in `policy.sh` must handle both forms.
- Plugin-level hooks fire for ALL sessions. Skill-level hooks (in SKILL.md frontmatter) fire only when that skill is active.
- `[[ "$path" == $glob ]]` does NOT recursively match `**`. The `match_glob` function converts `dir/**` patterns to prefix checks.
- Hook handlers run in parallel when multiple match the same event. Policy hooks must not depend on execution order.
- `stop-gate.sh` checks `stop_hook_active` to prevent infinite loops. If it blocked once, it lets go on retry.
