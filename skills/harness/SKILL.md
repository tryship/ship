---
name: harness
version: 2.0.0
description: >
  Activate AI harness enforcement. Registers the semantic convention
  check hook in .claude/settings.json. CONVENTIONS.md must exist in
  .ship/rules/semantic/. Use when: harness, activate rules, enable enforcement.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
---

# Ship: Harness

Activate the project's coding convention enforcement by registering
a hook entry in `.claude/settings.json`.

## Principal Contradiction

**Enforcement must be opt-in yet reliable once activated.**

The harness cannot be always-on at the plugin level because different
projects have different rules. But once activated, it must reliably
intercept every Write/Edit to enforce conventions.

## Process

1. Check `.ship/rules/semantic/CONVENTIONS.md` exists.
   If not → tell user to run `/ship:setup-harness` first and stop.

2. Read `.claude/settings.json` (create `{}` if missing).

3. Check if harness hook is already registered:
   Look for a PreToolUse hook with command containing
   `check-conventions.sh`.
   If found → "Harness is already active." and stop.

4. Add PreToolUse hook entry to `.claude/settings.json`,
   preserving all existing hooks:

   ```json
   {
     "matcher": "Write|Edit",
     "hooks": [
       {
         "type": "command",
         "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-conventions.sh",
         "statusMessage": "Reviewing coding conventions..."
       }
     ]
   }
   ```

5. Confirm: "Harness activated. Convention enforcement enabled."

## Hard Rules

1. Never create rule files. This skill only registers hooks.
2. Never modify existing hooks — only append new ones.
3. If CONVENTIONS.md is missing, stop immediately.

<Bad>
- Creating .ship/rules/ directory or any rule files
- Overwriting existing hooks in settings.json
- Activating when CONVENTIONS.md doesn't exist
- Modifying rule files during activation
</Bad>
