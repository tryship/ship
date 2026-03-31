# Harness v2 — Spec

## Investigation

### What was traced

**Files to remove (Policy v1):**
- `bin/policy-boundaries.sh` (223 lines) — PreToolUse for Write|Edit|Read|Grep|Glob. Sources `bin/lib/policy.sh`. Checks `no_access`, `read_only`, `allowed_paths`. No external consumers beyond `hooks/hooks.json`.
- `bin/policy-secrets.sh` (115 lines) — PreToolUse for Write|Edit. Sources `bin/lib/policy.sh`. Scans content for hardcoded patterns (AWS keys, GitHub PATs, OpenAI keys, private keys) + custom patterns from policy JSON. No external consumers.
- `bin/policy-operations.sh` (253 lines) — PreToolUse for Bash. Sources `bin/lib/policy.sh`. Checks blocked commands, dependency management (npm/pip/cargo), git operations (force push, push to main, branch delete, amend), pre-commit quality checks. No external consumers.
- `bin/policy-context.sh` (86 lines) — SessionStart. Sources `bin/lib/policy.sh`. Loads policy, merges base policy, migrates gitignore, builds summary. No external consumers.
- `bin/lib/policy.sh` (342 lines) — Shared library. Functions: `_policy_repo_root`, `load_policy`, `merge_policies`, `match_glob`, `match_regex`, `get_action`, `log_audit`. Sourced by: policy-boundaries, policy-secrets, policy-operations, policy-context, audit-logger.
- `skills/setup/templates/ship.policy.json` — Policy template with 5 sections.

**Files with dependencies that need modification:**

1. `hooks/hooks.json:4-13` — SessionStart references `policy-context.sh`
2. `hooks/hooks.json:14-29` — PreToolUse references `policy-boundaries.sh`, `policy-secrets.sh`, `policy-operations.sh`
3. `hooks/hooks.json:38-44` — PostToolUse references `audit-logger.sh`
4. `hooks/hooks.json:45-53` — Stop references `stop-gate.sh`
5. `hooks/hooks.json:54-62` — SessionEnd references `audit-logger.sh`
6. `bin/audit-logger.sh:22-24` — Sources `policy.sh`, calls `load_policy()`, uses `log_audit()`
7. `bin/stop-gate.sh:57-73` — Reads `workflow.phases` from `.ship/ship.policy.json`
8. `skills/auto/SKILL.md:146` — References `.ship/ship.policy.json`
9. `skills/setup/SKILL.md` — Entire Phase 4 Step C generates `ship.policy.json`
10. `AGENTS.md:28-32` — Documents policy hooks
11. `AGENTS.md:49` — References policy file location
12. `README.md:34,67` — References `ship.policy.json`
13. `TODO.md:5-6,11` — P0/P1 items reference policy

**Files NOT affected (workflow layer — kept as-is):**
- `bin/guard-orchestrator.sh` — Does NOT depend on policy.sh. Only checks `.claude/ship-coding.local.md` state file.
- `bin/post-compact.sh` — Does NOT depend on policy.sh. Only reads task artifacts.
- `bin/preamble.sh` — Does NOT depend on policy.sh. Checks for AGENTS.md/CLAUDE.md.
- `bin/setup-ship-coding.sh` — Creates state file, independent of policy.
- `bin/task-id.sh` — Pure task-id generation, no policy dependency.

### Existing relevant code

**stop-gate.sh workflow dependency (bin/stop-gate.sh:57-73):**
stop-gate reads `workflow.phases` from `ship.policy.json` to decide which phases are required/optional. With policy removed, this config needs a new home. The defaults are already hardcoded (lines 60-65: all required), and the policy file is optional (`if [ -f "$POLICY_JSON" ]`). Options: (a) keep defaults, move config to `rules.json` under a `workflow` key, (b) new standalone `.ship/workflow.json`, (c) just use the hardcoded defaults. Recommendation: move to `rules.json` — it already has per-project config.

**audit-logger.sh dependency (bin/audit-logger.sh:22-24):**
audit-logger currently sources `policy.sh` for: (1) `load_policy()` to check if audit is enabled, (2) `log_audit()` to write JSONL. In v2, audit is optional and AI-decided. If a project needs audit, AI generates a PostToolUse hook for it. The existing `audit-logger.sh` can be simplified to a standalone script that doesn't need policy.sh — just reads its own config from `rules.json`.

**hooks.json registration:**
The current hooks.json is at plugin level (`hooks/hooks.json`). Harness v2 hooks go in `.claude/settings.json` (project level). These are different locations. The plugin-level hooks.json will be slimmed down to just the workflow hooks (guard, stop-gate, post-compact). The harness hooks are project-level, managed by setup/harness/unharness skills.

### Unverified assumptions

1. Agent hook `type: "agent"` can return `hookSpecificOutput.additionalContext` — the schema shows this field exists for PostToolUse, but need to verify it works for PreToolUse agent hooks.
2. The `if` field in hook definitions filters before spawning the hook process — not tested empirically.
3. Haiku model cost per agent hook invocation — not benchmarked. Could be significant for projects with many Write/Edit operations.

## Requirements

1. Remove all Policy v1 files (6 files: 5 shell scripts + 1 template)
2. Remove policy references from `hooks/hooks.json` (keep workflow hooks)
3. Rewrite `skills/setup/SKILL.md` Phase 4 to generate AI-driven rules instead of `ship.policy.json`
4. Create `/ship:harness` skill (activate rules enforcement via settings.json hooks)
5. Create `/ship:unharness` skill (deactivate rules enforcement)
6. Decouple `bin/audit-logger.sh` from `policy.sh`
7. Decouple `bin/stop-gate.sh` from `ship.policy.json`
8. Update `AGENTS.md`, `README.md`, `TODO.md` to reflect new architecture
9. Preserve workflow layer unchanged (guard-orchestrator, post-compact, setup-ship-coding, preamble)

## Non-goals

- Implementing actual rule detection/generation logic in setup (that's AI runtime behavior, not code to write)
- Writing rule templates or preset rules (against design principle)
- Changing the workflow layer (guard-orchestrator, stop-gate orchestration logic, post-compact)
- Cross-platform adapters (Cursor, Codex — P2 in TODO)
- CI gate (stays in TODO, separate feature)
- Benchmark suite

## Acceptance Criteria

1. `bin/policy-*.sh` and `bin/lib/policy.sh` are deleted
2. `skills/setup/templates/ship.policy.json` is deleted
3. `hooks/hooks.json` only contains workflow hooks (guard-orchestrator, stop-gate, post-compact) — no policy hooks
4. `skills/setup/SKILL.md` Phase 4 generates `.ship/rules/` + `.claude/settings.json` hooks instead of `ship.policy.json`
5. `skills/harness/SKILL.md` exists and describes the activate flow
6. `skills/unharness/SKILL.md` exists and describes the deactivate flow
7. `bin/audit-logger.sh` works without sourcing `policy.sh`
8. `bin/stop-gate.sh` reads workflow config from `rules.json` instead of `ship.policy.json`
9. `AGENTS.md` accurately describes the new architecture
10. All remaining `.sh` scripts pass `shellcheck` (if installed)
11. No remaining references to `ship.policy.json` or `policy-boundaries` or `policy-secrets` or `policy-operations` in any active code (docs about migration are OK)
