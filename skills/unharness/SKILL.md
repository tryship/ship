---
name: unharness
version: 2.0.0
description: >
  Deactivate AI harness enforcement. Removes the convention check
  hook from .claude/settings.json. CONVENTIONS.md is preserved for
  re-activation. Use when: unharness, deactivate rules, disable
  enforcement, turn off harness.
allowed-tools:
  - Read
  - Edit
  - Bash
---

# Ship: Unharness

Deactivate the project's coding convention enforcement by removing
the hook entry from `.claude/settings.json`.

## Principal Contradiction

**Deactivation must be clean yet non-destructive.**

Removing hooks must not break other hooks in settings.json, and must
preserve CONVENTIONS.md so the user can re-activate with `/ship:harness`.

## Process

1. Read `.claude/settings.json`.
   If missing → "No harness is active (no settings.json found)." and stop.

2. Find and remove PreToolUse hook entries that match harness hooks.
   Identify by ANY of:
   - `command` containing `check-conventions.sh`
   - `statusMessage` containing "coding conventions"

3. Preserve ALL other hooks in settings.json.
   If the PreToolUse array becomes empty after removal, remove the
   PreToolUse key. If the hooks object becomes empty, remove it.

4. Do NOT delete `.ship/rules/` — CONVENTIONS.md is preserved for re-activation.

5. Confirm: "Harness deactivated. CONVENTIONS.md preserved in .ship/rules/semantic/."

## Hard Rules

1. Never delete rule files. This skill only removes hooks.
2. Never modify CONVENTIONS.md or AGENTS.md.
3. Preserve all non-harness hooks exactly as they were.

<Bad>
- Deleting .ship/rules/ or CONVENTIONS.md
- Removing non-harness hooks from settings.json
- Modifying CONVENTIONS.md during deactivation
- Deleting settings.json entirely instead of surgically removing entries
</Bad>
