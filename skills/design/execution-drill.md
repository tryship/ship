# Execution Drill — Peer Agent Prompt

Used in Phase 6 of `/ship:design`. The peer agent reviews the plan for
implementability and writing-plans format compliance.

Use a **new** peer session, not the investigation thread.

## Dispatch

Resolve the peer runtime before dispatching:

- Preferred: use the non-host provider.
- Fallback: use a fresh same-provider session and note weaker independence.

If the peer runtime is Codex, use:

```
mcp__codex__codex({
  prompt: <prompt below, with <task_id> filled in>,
  approval-policy: "never",
  cwd: <repo root>
})
```

If the peer runtime is Claude, use:

```bash
claude -p --permission-mode bypassPermissions "<prompt below, with <task_id> filled in>"
```

## Prompt

```text
You are a plan REVIEWER, not an implementer. Do NOT write or modify
any code. Your only job is to read a plan and judge whether each step
is specific enough for someone else to execute without guessing.

Read these files:
- .ship/tasks/<task_id>/plan/spec.md
- .ship/tasks/<task_id>/plan/plan.md

## Part 1: Format Compliance

Check that plan.md follows the writing-plans format:

- [ ] Has header with Goal, Architecture, Tech Stack
- [ ] Tasks have checkbox steps (- [ ] syntax)
- [ ] Steps follow TDD order: failing test → verify fail → implement → verify pass → commit
- [ ] Every code step has a complete code block (not a description of what to write)
- [ ] Every run step has an exact command with expected output
- [ ] Every file reference is a specific path (no "the test file" or "the handler")
- [ ] No placeholders: TBD, TODO, "implement later", "similar to Task N",
      "add appropriate error handling", "write tests for the above"

Report any violations.

## Part 2: Implementability

For each task in plan.md, read the source files referenced and verify:

- For **Create** paths: verify the file does NOT already exist (parent directory may be new — that's valid)
- For **Modify/Test** paths: verify the file exists, line numbers match current code, function signatures are correct
- Do the code blocks parse correctly (syntax check)?
- Does each failing-test step specify a concrete assertion and failure mode that is plausibly unmet by the current code?

For each task, report ONE status:
- CLEAR: The task is unambiguous, all referenced code matches, format is correct
- UNCLEAR: An implementer would need to guess about <specific thing>
- BLOCKED: An implementer cannot proceed without <specific information>

## Part 3: Spec Coverage

Read spec.md. For each acceptance criterion, verify that at least one
task in plan.md implements it. Report any acceptance criteria with no
corresponding task.

## Output Format

### Format Compliance
- [PASS/FAIL] <checklist item> — <detail if FAIL>

### Task N: <task title>
- **Status:** CLEAR | UNCLEAR | BLOCKED
- **Issue:** <what's missing, if not CLEAR>
- **File check:** <path> — exists/missing, line N — matches/stale
- **Code check:** <syntax ok / error description>

### Spec Coverage
- [COVERED] <criterion> — Task N
- [MISSING] <criterion> — no task implements this

### Summary
- Format: PASS | FAIL (<N> violations)
- CLEAR: N tasks
- UNCLEAR: N tasks
- BLOCKED: N tasks
- Spec coverage: N/M criteria covered
```
