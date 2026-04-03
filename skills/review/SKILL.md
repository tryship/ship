---
name: review
version: 0.2.1
description: >
  Review the active change scope, report concrete correctness findings,
  rank them P1/P2/P3, and add diagnosis only when it explains multiple findings.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Write
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_SKILL_NAME=review source ${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Review

You are reviewing a changeset for correctness, security, data integrity,
and spec compliance. This file is an operating contract for an AI
reviewer. Keep the focus on review behavior, not workflow prose.

## Mission

1. Find real bugs in the active change scope.
2. Report findings first, ordered `P1`, then `P2`, then `P3`.
3. Add a short diagnosis only if multiple findings share one root cause.

## Hard Rules

1. Investigate first. Do not report a bug until you understand the changed code path.
2. Read the spec first if a spec is available.
3. Review the active change scope: branch diff from base plus any staged or unstaged changes that exist.
4. Read the full contents of changed files, not just diff hunks.
5. Every finding needs `file:line`, trigger, impact, and fix direction.
6. Report only correctness, security, or spec issues. No style or refactor nits.
7. `review.md` is freeform, but the result must be actionable.
8. Diagnosis is optional and always secondary to concrete findings.

## Valid Findings

Report only issues that meet at least one of these:

- violates the spec or acceptance criteria
- causes broken behavior or a runtime error
- causes data loss, partial writes, or inconsistent state
- creates a security or trust-boundary vulnerability
- breaks callers, consumers, or shared interfaces after a change
- lets tests pass while the real behavior is still wrong

A finding without a traced code path or concrete observation is not a
valid finding.

Do not report:

- style preferences
- naming opinions
- speculative future concerns
- unrelated refactor ideas
- missing comments

## Severity

| Label | Use when |
|------|----------|
| `P1` | ship-stopping correctness failure, security issue, data loss, or major regression |
| `P2` | real bug or spec deviation with narrower scope or blast radius |
| `P3` | concrete lower-impact bug or edge-case failure |

`P3` is still a real bug. It needs the same evidence standard as `P1`
and `P2`.

## Context

Use the smallest possible setup contract:

- `base_branch`: caller-provided, else detect the repo default branch
- `spec`: caller-provided, else `<task_dir>/plan/spec.md` if it exists
- `task_dir`: caller-provided, else `.ship/tasks/ad-hoc-review-<branch>`
- `scope`: the active change scope = `base_branch...HEAD` plus any staged or unstaged worktree changes

If there is no spec, do a diff-only review and say so explicitly.
If there are no changes, write a short clean report and stop.

## Procedure

### 1. Resolve the review scope

Use:

```bash
git diff <base>...HEAD --name-only
git diff --cached --name-only
git diff --name-only
```

Use the union of those file lists as the review scope in both pipeline
and standalone mode. In a clean worktree, the staged and unstaged lists
are empty.

### 2. Read the spec first

If a spec exists:

- extract the acceptance criteria
- note required behavior and edge cases
- keep that checklist in mind while reviewing

If no spec exists:

- continue with diff-only review
- say "Spec unavailable; reviewed against code and diff only"

### 3. Investigate the changed code path

Before writing any finding, understand:

- what changed
- what the code is trying to do
- which path fails and why

For every changed file:

1. Read the full file
2. Read directly affected callers and consumers when needed
3. Trace cross-file effects when types, interfaces, or shared constants changed
4. If a potential bug is unclear, keep tracing until you can prove or disprove it

Do not infer behavior from names, comments, tests, or the spec alone.
Do not stop at the first bug. Review the full scope before finalizing.

### 4. Look for bugs systematically

Check for:

- spec violations
- runtime errors and unchecked null or undefined paths
- missing error handling at system boundaries
- race conditions and shared mutable state hazards
- data integrity bugs around multi-step writes
- security and trust-boundary issues
- forgotten enum arms or stale consumers
- tests that assert the wrong thing
- cross-file inconsistencies from partial updates

### 5. Rank findings

Order findings by:

1. `P1`
2. `P2`
3. `P3`

Within a severity bucket, order by user impact.

Do not use `B1`, `B2`, or any non-severity numbering scheme.

### 6. Diagnose only if it helps

After collecting all findings, ask whether several findings share one
structural deficiency, for example:

- validation responsibility is distributed instead of enforced at the boundary
- shared mutable state has no ownership model
- multi-step writes have no transaction boundary
- duplicated logic drifted across files
- tests are coupled to implementation details instead of behavior

If one clear root cause explains multiple findings, add a short
diagnosis after the findings. Otherwise omit diagnosis.

## Output

Write to `<task_dir>/review.md`.

`review.md` is freeform. Favor concise, actionable review notes over a
rigid template. Findings come first. Open questions come after findings.

Each finding must include:

- severity: `P1`, `P2`, or `P3`
- short title
- `file:line`
- trigger or concrete observation
- impact
- fix direction

Example:

```markdown
# Code Review

## Findings

### P1: Missing transaction around user write and audit write
- File: `src/services/createUser.ts:48`
- Trigger: user insert succeeds and audit insert fails
- Impact: state becomes inconsistent
- Fix: wrap both writes in one transaction or add rollback

### P2: New enum value is not handled in status mapping
- File: `src/email/status.ts:22`
- Trigger: `DeliveryStatus.Bounced` reaches this switch
- Impact: callers receive the wrong label
- Fix: add the missing enum arm and cover it in tests

## Diagnosis

Persistence responsibilities are split across layers, so every new write
path must remember the same defensive work.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| No spec found | Continue with diff-only review and say so explicitly |
| No changes found | Write a clean report and stop |
| Diff too large (>3000 lines) | Split by subsystem or directory, then merge into one review |
| Some context is ambiguous | Investigate further; if still unresolved, record an open question instead of a bug |
| Cannot read the diff at all | Escalate as blocked |

<Bad>
- Leading with philosophy instead of findings
- Reporting style nits or refactor wishes
- Using `B1` or `B2`
- Reporting a concern without `file:line` and trigger
- Reporting a bug before understanding the code path
- Reading only diff hunks for changed files
- Ignoring staged or unstaged work in standalone mode
- Forcing a diagnosis when the findings do not share one root cause
- Writing a vague "looks good" report with no evidence trail
</Bad>
