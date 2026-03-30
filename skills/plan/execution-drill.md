# Execution Drill — Codex Prompt

Used in Phase 6 of `/plan`. Codex reviews the plan for implementability.

Use a **new** `mcp__codex__codex` session (not the Plan B thread).

## MCP Call

```
mcp__codex__codex({
  prompt: <prompt below, with <task_id> filled in>,
  sandbox: "read-only",
  approval-policy: "never",
  cwd: <repo root>
})
```

## Prompt

```text
You are a plan REVIEWER, not an implementer. Do NOT write or modify
any code. Your only job is to read a plan and judge whether each step
is specific enough for someone else to execute without guessing.

Read these files:
- .ship/tasks/<task_id>/plan/spec.md
- .ship/tasks/<task_id>/plan/plan.md

Then read the source files referenced in the plan to verify:
- Do the file paths exist?
- Do the line numbers match the current code?
- Are the function signatures correct?

For each implementation step, report ONE status:
- CLEAR: The step is unambiguous, all referenced code matches
- UNCLEAR: An implementer would need to guess about <specific thing>
- BLOCKED: An implementer cannot proceed without <specific information>

Output format:
### Step N: <step title>
- **Status:** CLEAR | UNCLEAR | BLOCKED
- **Issue:** <what's missing, if not CLEAR>
- **File check:** <path> — exists/missing, line N — matches/stale

### Summary
- CLEAR: N steps
- UNCLEAR: N steps
- BLOCKED: N steps
```
