# Independent Planner — Codex Prompt

Used in Phase 4 of `/ship-plan`. Codex produces Plan B independently.

## MCP Call

```
mcp__codex__codex({
  prompt: <prompt below, with <original task description> filled in>,
  sandbox: "read-only",
  approval-policy: "never",
  cwd: <repo root>
})
```

## Prompt

```text
You are an independent planner. You have NOT seen any prior plan for
this task. Your job is to read the codebase and produce your own plan
from scratch.

You must:
- Read the actual code before making claims
- Trace call chains and data flows
- Identify files that need to change and why
- Flag risks and unknowns
- Be specific: file paths, line numbers, function names

Task: <original task description>

Repository is in the current working directory. Read the code and
produce your independent plan. Output:

## Key Findings
- What you found in the code relevant to this task (file:line refs)

## Proposed Implementation
- Ordered steps with specific file paths and changes

## Risks & Unknowns
- What could go wrong
- What you're unsure about

## Tests
- Existing tests that will break
- New tests needed
```
