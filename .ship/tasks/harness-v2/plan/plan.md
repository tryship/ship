# Harness v2 — Implementation Plan

## Story 1: Delete Policy v1 files

Delete the following files:
- `bin/policy-boundaries.sh`
- `bin/policy-secrets.sh`
- `bin/policy-operations.sh`
- `bin/policy-context.sh`
- `bin/lib/policy.sh`
- `skills/setup/templates/ship.policy.json`

After deletion, check that `bin/lib/` is empty and remove it if so.

**Test:** `ls bin/policy-*.sh bin/lib/policy.sh` should return "No such file or directory" for all.

## Story 2: Slim down hooks/hooks.json

Current `hooks/hooks.json` (hooks/hooks.json:1-69) has 5 event types. Remove:
- `SessionStart` entirely (only contained `policy-context.sh`)
- `PreToolUse` entirely (only contained `policy-boundaries.sh`, `policy-secrets.sh`, `policy-operations.sh`)
- `PostToolUse` entirely (only contained `audit-logger.sh` — audit moves to project-level)
- `SessionEnd` entirely (only contained `audit-logger.sh`)

Keep:
- `Stop` → `stop-gate.sh` (workflow enforcement)

Add entries the workflow layer still needs:
- `PreToolUse` → `guard-orchestrator.sh` (was previously registered but not in hooks.json — check if it's elsewhere)

Wait — investigation shows `guard-orchestrator.sh` is NOT in `hooks/hooks.json`. Let me verify.

Actually re-reading hooks/hooks.json:14-29, PreToolUse has `policy-boundaries.sh`, `policy-secrets.sh` for Write|Edit|Read|Grep|Glob, and `policy-operations.sh` for Bash. guard-orchestrator.sh is NOT registered in hooks.json — it must be registered somewhere else or it was removed.

After investigation: `guard-orchestrator.sh` has a comment saying "Runs IN PARALLEL with guard-orchestrator.sh" in policy-operations.sh:8, suggesting they used to run together. But hooks.json doesn't list it. Check if there's another hook registration point.

**Investigation result:** `guard-orchestrator.sh` and `post-compact.sh` are NOT registered in any JSON config file (verified via `grep -rn 'guard-orchestrator' --include='*.json'`). This is a pre-existing issue — out of scope for this migration. Do NOT add them.

Resulting `hooks/hooks.json`:
```json
{
  "description": "Ship plugin hooks — workflow quality gates",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/bin/stop-gate.sh"
          }
        ]
      }
    ]
  }
}
```

**Known gap (out of scope):** `guard-orchestrator.sh` and `post-compact.sh` are documented as hooks but have no registration. This predates the migration and should be addressed separately.

**Test:** `jq '.hooks | keys' hooks/hooks.json` should return `["Stop"]`.

## Story 3: Decouple stop-gate.sh from ship.policy.json

`bin/stop-gate.sh:57-73` reads workflow phase requirements from `.ship/ship.policy.json`.

Change to read from `.ship/rules/rules.json` instead:
```bash
# Old (lines 57-73):
POLICY_JSON="$REPO_ROOT/.ship/ship.policy.json"
if [ -f "$POLICY_JSON" ]; then
  PLAN_REQUIRED=$(jq -r '.workflow.phases.plan // "required"' "$POLICY_JSON")
  ...
fi

# New:
RULES_JSON="$REPO_ROOT/.ship/rules/rules.json"
if [ -f "$RULES_JSON" ]; then
  PLAN_REQUIRED=$(jq -r '.workflow.phases.plan // "required"' "$RULES_JSON")
  REVIEW_REQUIRED=$(jq -r '.workflow.phases.review // "required"' "$RULES_JSON")
  VERIFY_REQUIRED=$(jq -r '.workflow.phases.verify // "required"' "$RULES_JSON")
  QA_REQUIRED=$(jq -r '.workflow.phases.qa // "required"' "$RULES_JSON")
  SIMPLIFY_REQUIRED=$(jq -r '.workflow.phases.simplify // "required"' "$RULES_JSON")
fi
```

Add `workflow` section to `rules.json` schema (in spec — for AI to generate during setup):
```json
{
  "version": 1,
  "workflow": {
    "phases": {
      "plan": "required",
      "review": "required",
      "verify": "required",
      "qa": "optional",
      "simplify": "optional"
    }
  },
  "structural": [...],
  "semantic": [...]
}
```

**Test:** `echo '{"workflow":{"phases":{"plan":"required","qa":"optional"}},"structural":[],"semantic":[]}' | jq -r '.workflow.phases.plan'` should return `required`.

## Story 4: Decouple audit-logger.sh from policy.sh

`bin/audit-logger.sh` currently:
1. Sources `policy.sh` (line 22)
2. Calls `load_policy()` to check `audit.enabled` (line 24)
3. Uses `log_audit()` from policy.sh for writing JSONL (lines 53, 63, 74)

In v2, audit-logger is no longer a plugin-level hook. It becomes an optional AI-generated hook at project level. But the script itself can remain as a standalone utility.

Changes:
- Remove `source "$SCRIPT_DIR/lib/policy.sh"` and `load_policy || exit 0`
- Remove policy-dependent config reading (audit.enabled, audit.events.*, retention_days)
- Simplify to: always log if the script is called (if it's registered as a hook, it should log)
- Inline the `log_audit` function (copy from policy.sh, ~20 lines)
- Read audit config from `rules.json` instead of `ship.policy.json`:
  ```bash
  RULES_JSON="$REPO_ROOT/.ship/rules/rules.json"
  if [ -f "$RULES_JSON" ]; then
    audit_enabled=$(jq -r '.audit.enabled // false' "$RULES_JSON")
  fi
  ```

**Test:** Create a minimal rules.json with `{"audit":{"enabled":true},"structural":[],"semantic":[]}`, pipe hook input JSON, verify a `.ship/audit/YYYY-MM-DD.jsonl` entry is created.

## Story 5: Rewrite setup SKILL.md Phase 4

Current Phase 4 in `skills/setup/SKILL.md:206-247` generates `ship.policy.json` from a template.

Replace with a new Phase 4 that:

### Step A: AI Rule Discovery (replaces template-based policy generation)

Instead of reading `templates/ship.policy.json` and filling fields, the setup skill now instructs the AI to:

1. Analyze the project codebase:
   - Scan directory structure for layering patterns
   - Analyze import/require graphs for dependency boundaries
   - Sample error handling, validation, logging patterns
   - Detect naming conventions
   - Identify security-sensitive patterns (credential files, env usage)
   - Check existing linter configs for implicit conventions

2. Read existing documentation:
   - CONTRIBUTING.md, STYLE_GUIDE.md, ARCHITECTURE.md
   - Linter configs (.eslintrc, ruff.toml, tsconfig.json)
   - CLAUDE.md / AGENTS.md

3. Present discovered rules to user for confirmation:
   - Show each rule with evidence and confidence level
   - User toggles on/off, adds missing rules
   - User confirms with "done"

### Step B: Generate rule files

After confirmation, generate:
- `.ship/rules/rules.json` — rule index with `structural`, `semantic`, `workflow` sections
- `.ship/rules/structural/*.sh` — check scripts (AI-authored)
- `.ship/rules/semantic/*.md` — convention docs (AI-authored)
- `.ship/rules/enforce-structural.sh` — router script (AI-authored)

### Step C: Register hooks

Merge two hook entries into `.claude/settings.json` (project-level):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "bash .ship/rules/enforce-structural.sh",
          "statusMessage": "Checking structural rules..."
        }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "agent",
          "prompt": "You are a code convention enforcer. Read .ship/rules/rules.json to find all enabled semantic rules. For each applicable rule (check scope against the file being written), read the rule's .md file from .ship/rules/semantic/. Then verify the code in $ARGUMENTS follows those conventions. If violations found, return JSON with hookSpecificOutput.additionalContext describing each violation and how to fix it. If no violations, return nothing.",
          "model": "claude-haiku-4-5-20251001",
          "statusMessage": "Reviewing coding conventions..."
        }]
      }
    ]
  }
}
```

If `.claude/settings.json` already exists, merge hooks (preserve existing entries).

### Step D: Optionally generate audit hook

If AI determines the project needs audit logging, add a PostToolUse hook entry to `.claude/settings.json` that calls `audit-logger.sh`.

### Step E: Update AGENTS.md + commit

Update AGENTS.md to describe the new harness architecture. Commit all generated files.

**Test:** After running setup on a test project, `.ship/rules/rules.json` exists and is valid JSON. `.claude/settings.json` has the two PreToolUse hook entries.

## Story 6: Create /ship:harness skill

Create `skills/harness/SKILL.md`:

```markdown
---
name: harness
version: 1.0.0
description: >
  Activate AI harness enforcement. Registers structural and semantic
  rule hooks in .claude/settings.json. Rules must exist in .ship/rules/.
  Use when: harness, activate rules, enable enforcement.
allowed-tools:
  - Read
  - Edit
  - Bash
  - AskUserQuestion
---

# Ship: Harness

Activate the project's coding convention enforcement.

## Process

1. Check `.ship/rules/rules.json` exists. If not → tell user to run `/ship:setup` first.
2. Read `.claude/settings.json` (create if missing).
3. Check if harness hooks already registered (look for statusMessage "Checking structural rules..."). If yes → already active, confirm and exit.
4. Merge two PreToolUse hook entries into settings.json (preserve existing hooks).
5. Count enabled structural and semantic rules from rules.json.
6. Confirm: "Harness activated. N structural + M semantic rules enabled."
```

**Test:** After running `/ship:harness`, `jq '.hooks.PreToolUse | length' .claude/settings.json` returns at least 2.

## Story 7: Create /ship:unharness skill

Create `skills/unharness/SKILL.md`:

```markdown
---
name: unharness
version: 1.0.0
description: >
  Deactivate AI harness enforcement. Removes structural and semantic
  rule hooks from .claude/settings.json. Rule files in .ship/rules/
  are preserved. Use when: unharness, deactivate rules, disable enforcement.
allowed-tools:
  - Read
  - Edit
  - Bash
---

# Ship: Unharness

Deactivate the project's coding convention enforcement.

## Process

1. Read `.claude/settings.json`. If missing → nothing to deactivate, confirm and exit.
2. Remove PreToolUse hook entries that match harness hooks (identify by `statusMessage` containing "structural rules" or "coding conventions", or by command path containing `.ship/rules/`).
3. Preserve all other hooks in settings.json.
4. Do NOT delete `.ship/rules/` — rules are preserved for re-activation.
5. Confirm: "Harness deactivated. Rules preserved in .ship/rules/."
```

**Test:** After running `/ship:unharness`, harness-specific hooks are removed but other hooks remain.

## Story 8: Update documentation

### AGENTS.md

Rewrite the Architecture section:
- Remove "Policy layer" references
- Replace with "Harness layer" description (structural + semantic rules)
- Update Repository Map (remove bin/lib/, remove policy scripts)
- Update Code Style (remove policy.sh sourcing requirement)
- Update Boundaries (remove policy-specific never-do items)
- Update Gotchas (remove policy-related gotchas)

### README.md

- Replace "generates security policy (ship.policy.json)" with "generates AI-driven coding convention rules (.ship/rules/)"
- Update skill table to include `/ship:harness` and `/ship:unharness`

### TODO.md

- Remove P0 "CI gate" and "Rules system" (rules system IS harness v2)
- Remove P1 "Bash redirection bypass" (no longer relevant — no policy-boundaries.sh)
- Update "Policy Schema" section in Architecture Decisions
- Add new items: "Agent hook cost optimization", "Rule evolution/re-scan"

### skills/auto/SKILL.md:146

Change:
```
If `.ship/ship.policy.json` is missing: suggest `/setup` but do not block.
```
To:
```
If `.ship/rules/rules.json` is missing: suggest `/setup` but do not block.
```

## Story 9: Fix .ship/ gitignore in setup-ship-coding.sh

`bin/setup-ship-coding.sh:52-57` adds `.ship/` to `.gitignore`. But `.ship/rules/` needs to be git-tracked (team-shared rules). Change to gitignore only `.ship/tasks/` and `.ship/audit/` instead.

```bash
# Old (line 54):
if [ ! -f "$GITIGNORE" ] || ! grep -qxF ".ship/" "$GITIGNORE" 2>/dev/null; then
  echo ".ship/" >> "$GITIGNORE"
fi

# New:
for ENTRY in ".ship/tasks/" ".ship/audit/"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$ENTRY" "$GITIGNORE" 2>/dev/null; then
    echo "$ENTRY" >> "$GITIGNORE"
  fi
done
```

Also handle migration: if `.ship/` is already in `.gitignore`, replace it with the narrower entries (similar to what `policy-context.sh:37-49` already did).

**Test:** After running setup-ship-coding.sh, `.gitignore` should contain `.ship/tasks/` and `.ship/audit/` but NOT `.ship/`.

## Story 10: Migration path for existing ship.policy.json

In the rewritten setup (Story 5), add a migration check:

1. If `.ship/ship.policy.json` exists when setup runs:
   - Read `workflow.phases` from it
   - Seed the `workflow` section of the new `rules.json` with those values
   - Inform user: "Migrated workflow phase config from ship.policy.json. The old policy file is no longer used and can be deleted."
2. Do NOT auto-delete the old file — let user decide.

This ensures existing projects don't lose their workflow phase customizations.

## Story 11: Clean up and verify

1. `grep -rn 'ship\.policy\.json\|policy-boundaries\|policy-secrets\|policy-operations\|policy-context\|policy\.sh' --include='*.sh' --include='*.json' --include='*.md'` — verify no stale references in active code (docs about migration are OK)
2. `shellcheck bin/*.sh` — verify all remaining scripts pass (if shellcheck installed)
3. `jq . hooks/hooks.json` — verify valid JSON
4. Verify `.ship/rules/` directory structure is documented but NOT pre-populated (no templates)

## Execution Order

```
[1: Delete Policy v1] → [2: Slim hooks.json] → [3: Decouple stop-gate] → [4: Decouple audit-logger] → [9: Fix gitignore]
                                                                                                              ↓
                                                                                   [5: Rewrite setup + 10: migration] ─┐
                                                                                   [6: Create harness]                 ─┤→ [8: Update docs] → [11: Verify]
                                                                                   [7: Create unharness]               ─┘
```

Stories 1-4, 9 must execute sequentially (each depends on prior removals/changes).
Stories 5-7 can execute in parallel (independent new files).
Story 8 executes after all others (needs final state to document accurately).
Story 11 executes last (verification).

```
[1: Delete Policy v1] → [2: Slim hooks.json] → [3: Decouple stop-gate] → [4: Decouple audit-logger]
                                                                                    ↓
                                                              [5: Rewrite setup] ─┐
                                                              [6: Create harness] ─┤→ [8: Update docs] → [9: Verify]
                                                              [7: Create unharness]┘
```
