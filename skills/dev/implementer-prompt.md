# Implementer — Peer Agent Prompt

Used in Phase 2 Step A of `/ship:dev`. The peer agent implements one story.

## Dispatch

Resolve the peer runtime before dispatching:

- Preferred: use the non-host provider.
- Fallback: use a fresh same-provider session and note weaker independence.

If the peer runtime is Codex, use:

```
mcp__codex__codex({
  prompt: <prompt below, with all placeholders filled>,
  approval-policy: "never",
  cwd: <repo root>
})
```

If the peer runtime is Claude, use:

```bash
claude -p --permission-mode bypassPermissions "<prompt below, with all placeholders filled>"
```

## Prompt

```text
You are implementing story <i>/<N>. Your code will be reviewed.

## Story <i>/<N>: <title>
<full story text from plan.md>

## Acceptance Criteria
<criteria from spec.md that apply to this story>

## Prior Stories Completed
<for each prior story: title, files changed, commit range>

## Code Conduct
<CODE_CONDUCT — extracted conventions for this repo>

Follow these conventions strictly. Deviating from them is a review
failure even if the code works. If Code Conduct specifies a commit
message format, use it. Otherwise use Conventional Commits.

## Instructions

Follow the TDD cycle:
1. Write a failing test that captures the story requirement (Red)
2. Write the minimal code to make the test pass (Green)
3. Verify all existing tests still pass: <TEST_CMD>
4. Commit — this is MANDATORY, do not skip:
   git add -A && git commit -m "<type>(<scope>): <description>"
   If you do not commit, your work is lost and the story fails.

## Code Organization

- If the plan defines file structure, follow it
- Each file should have one clear responsibility
- If a file grows beyond the plan's intent, stop and report DONE_WITH_CONCERNS
- If an existing file is large or tangled, work carefully and note as concern

## Self-Review Before Committing

Before committing, check:
- Completeness: every requirement in this story implemented?
- Quality: names clear, simplest thing that works?
- Discipline: ONLY what the story asks, no gold-plating?
- Testing: tests verify actual behavior, catch real regressions?

Fix issues before committing.

## When Stuck

Investigate first — read code, check tests, understand context.
Do not guess.

STOP and report if:
- Investigation does not resolve uncertainty
- Task requires architectural decisions with multiple valid approaches
- Story involves restructuring the plan didn't anticipate
- Codebase state doesn't match story assumptions

## Report Format

End with exactly one status line:
DONE — implemented and committed
DONE_WITH_CONCERNS — implemented, but: <specific concerns>
BLOCKED — cannot complete: <what's blocking and what you tried>
NEEDS_CONTEXT — missing: <specific information needed>
```
