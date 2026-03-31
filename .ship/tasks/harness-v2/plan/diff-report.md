# Diff Report — Plan A Self-Review

⚠ Plan B was self-generated, not independent (Codex MCP unavailable).

## Convergence Points

- Delete all Policy v1 files (bin/policy-*.sh, bin/lib/policy.sh, template)
- Decouple stop-gate.sh and audit-logger.sh from policy.sh
- Create harness/unharness skills
- Rewrite setup SKILL.md to generate AI-driven rules
- Update all documentation
- Preserve workflow layer unchanged

## Divergences

### D1: guard-orchestrator.sh and post-compact.sh are not registered in hooks.json

- **Plan A says:** Add guard-orchestrator.sh to hooks.json PreToolUse after removing policy hooks.
- **Self-review found:** guard-orchestrator.sh is NOT registered in any JSON config file (`grep -rn 'guard-orchestrator' --include='*.json'` returns nothing). Neither is post-compact.sh. Both are referenced in comments and docs as if they're active, but they have no hook registration.
- **Code evidence:** `hooks/hooks.json` only contains: SessionStart→policy-context, PreToolUse→policy-boundaries+policy-secrets (Write|Edit|Read|Grep|Glob) + policy-operations (Bash), PostToolUse→audit-logger, Stop→stop-gate, SessionEnd→audit-logger. No guard-orchestrator, no post-compact.
- **Disposition:** patched — Plan A should NOT add guard-orchestrator/post-compact to hooks.json. This is a pre-existing issue and out of scope. Plan A should document it as a known gap but not fix it. The slimmed hooks.json should only contain Stop→stop-gate.

### D2: setup-ship-coding.sh gitignores all of .ship/

- **Plan A says:** nothing about setup-ship-coding.sh
- **Self-review found:** `bin/setup-ship-coding.sh:54` adds `.ship/` to `.gitignore`. But `.ship/rules/` needs to be git-tracked (team-shared). This conflicts with the harness v2 design.
- **Code evidence:** `bin/setup-ship-coding.sh:52-57` — `echo ".ship/" >> "$GITIGNORE"`
- **Disposition:** patched — Plan A needs a story to update setup-ship-coding.sh to gitignore `.ship/tasks/` and `.ship/audit/` instead of all `.ship/`. Note: policy-context.sh already had a migration for this (lines 37-49), so some repos may already have the narrower ignores.

### D3: Existing .ship/ship.policy.json migration path

- **Plan A says:** nothing about existing policy files
- **Self-review found:** Users who already ran `/ship:setup` have a `.ship/ship.policy.json`. After the migration, this file becomes orphaned. Setup should detect it and offer to migrate (extract workflow phases, then suggest running harness setup).
- **Code evidence:** `skills/setup/SKILL.md:157` — checks for existing `.ship/ship.policy.json`
- **Disposition:** patched — Add to Story 5 (setup rewrite): if `.ship/ship.policy.json` exists, read `workflow.phases` from it and seed `rules.json` workflow section, then suggest user can delete the old file.

### D4: hooks.json after cleanup is nearly empty

- **Plan A says:** hooks.json keeps Stop→stop-gate and adds PreToolUse→guard-orchestrator
- **Self-review found:** Per D1, guard-orchestrator was never registered. So hooks.json only has Stop→stop-gate. This means the plugin hooks.json is very minimal. Is that acceptable?
- **Disposition:** confirmed — Yes, this is fine. The plugin's job is shrinking: plugin-level hooks handle only workflow enforcement (stop-gate). Project-level hooks in .claude/settings.json handle rule enforcement. This is the correct split.

## Summary

- Confirmed: 6 points
- Patched: 3 (D1: don't add unregistered hooks, D2: fix .ship/ gitignore, D3: migration path)
- Proven-false: 0
- Escalated: 0
