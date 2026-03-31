---
name: ship-dev
version: 0.3.0
description: Execute implementation stories from a plan. Codex implements each story via MCP, Claude reviews spec compliance and code correctness. Stories run sequentially; review must pass before the next story starts.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - mcp__codex__codex
  - mcp__codex__codex-reply
---

# Ship: Implement

Execute implementation stories from a plan. Each story: Codex implements
via MCP, Claude reviews spec compliance + code correctness, targeted
fix on failure. Stories run sequentially; review must pass before the
next story starts.

## Principal Contradiction

**The code's actual behavior vs the spec's expected behavior.**

Implementation fails not because code "looks wrong" but because it
behaves differently from what the spec requires. The adversary is the
gap between what was written and what was intended. Codex generates,
Claude discriminates — different models, different blind spots.

## Core Principle

```
CODEX GENERATES, CLAUDE DISCRIMINATES.
EVERY FINDING NEEDS FILE:LINE + EVIDENCE.
```

Separation of concerns: Codex implements with only the story context
it needs. Claude reviews without having watched the implementation
happen — no accumulated leniency, no rationalization.

## Process Flow

```dot
digraph implement {
    rankdir=TB;

    "Start" [shape=doublecircle];
    "Read spec + plan, detect tooling" [shape=box];
    "Stories remaining?" [shape=diamond];
    "Record start SHA" [shape=box];
    "Codex implements story (MCP)" [shape=box];
    "Commits exist?" [shape=diamond];
    "Claude reviews (fresh Agent)" [shape=box];
    "Verdict?" [shape=diamond];
    "Record context, next story" [shape=box];
    "Codex targeted fix (MCP)" [shape=box];
    "Fix rounds exhausted?" [shape=diamond];
    "Run full test suite" [shape=box];
    "Tests pass?" [shape=diamond];
    "STOP: BLOCKED — story failed after max retries" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];
    "Done" [shape=doublecircle];

    "Start" -> "Read spec + plan, detect tooling";
    "Read spec + plan, detect tooling" -> "Stories remaining?";
    "Stories remaining?" -> "Record start SHA" [label="yes"];
    "Stories remaining?" -> "Run full test suite" [label="no"];
    "Record start SHA" -> "Codex implements story (MCP)";
    "Codex implements story (MCP)" -> "Commits exist?";
    "Commits exist?" -> "Claude reviews (fresh Agent)" [label="yes"];
    "Commits exist?" -> "STOP: BLOCKED — story failed after max retries" [label="no, claimed done"];
    "Claude reviews (fresh Agent)" -> "Verdict?";
    "Verdict?" -> "Record context, next story" [label="PASS"];
    "Verdict?" -> "Codex targeted fix (MCP)" [label="FAIL"];
    "Codex targeted fix (MCP)" -> "Fix rounds exhausted?";
    "Fix rounds exhausted?" -> "Claude reviews (fresh Agent)" [label="no, re-review"];
    "Fix rounds exhausted?" -> "STOP: BLOCKED — story failed after max retries" [label="yes, max 2"];
    "Record context, next story" -> "Stories remaining?";
    "Run full test suite" -> "Tests pass?";
    "Tests pass?" -> "Done" [label="yes"];
    "Tests pass?" -> "Codex targeted fix (MCP)" [label="no, regression"];
}
```

## Roles

| Role | Who | Why |
|------|-----|-----|
| Orchestrator | **You (Claude)** | Coordinate stories, never write code |
| Implementor | **Codex** (via MCP) | Fresh session per story, code generation |
| Reviewer | **Claude Agent** (fresh per review) | Different model = different blind spots |
| Targeted fixer | **Codex** (via MCP) | Surgical fixes, not re-implementation |

**Why different models for implement vs review:** This is the GAN
architecture — generator and discriminator must have different
cognitive biases to catch each other's blind spots. Same-model
review degrades to self-review.

## Hard Rules

1. You never write code, read diffs for review, or run tests yourself. Coordination metadata (git rev-parse, git diff --name-only, git status) is allowed.
2. Codex implements via MCP, not CLI. One story per session.
3. Claude Agent reviews fresh each time — no accumulated context.
4. Every review finding must include file:line + reproducible evidence.
5. Stories run sequentially. No parallelism. No skipping review.
6. FAIL means targeted fix, not full re-implementation.

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Spec + plan read | Acceptance criteria extracted, TEST_CMD found | AskUserQuestion |
| Implement → Review | STORY_HEAD_SHA != STORY_START_SHA (commits exist) | BLOCKED |
| Review → Next story | Verdict is PASS or PASS_WITH_CONCERNS | Targeted fix (max 2) |
| All stories → Done | Full test suite passes | Targeted fix for regression |

No story advances without passing its gate.

---

## Phase 1: Setup

1. Read **acceptance criteria** (from spec file, or derived from user request).
2. Read **implementation stories** (from plan file, or single story for small tasks).
   Accept any heading format: `## Story N`, `## Step N`, `## N. Title`,
   or numbered/bulleted lists. Normalize as ordered stories.
3. Detect the repo's test command by inspecting project root:
   - `Makefile` → `make test`
   - `package.json` → `npm test` / `pnpm test` / `yarn test`
   - `pytest.ini` / `pyproject.toml` → `pytest`
   - `go.mod` → `go test ./...`
   - `Cargo.toml` → `cargo test`
   - `mix.exs` → `mix test`
   - `build.gradle` / `pom.xml` → `./gradlew test` / `mvn test`
   - `.csproj` / `.sln` → `dotnet test`
   - `Gemfile` → `bundle exec rspec`
   Also check `CLAUDE.md`/`AGENTS.md` and CI configs. If none found,
   AskUserQuestion. Record as `TEST_CMD`.
4. Extract code conduct from `CLAUDE.md`, `AGENTS.md`, lint/formatter
   configs, and existing code patterns. Record as `CODE_CONDUCT`.

### Locating input

1. **Caller provides paths** → use them directly.
2. **Caller provides a task directory** → look for spec/plan files inside.
3. **No formal plan or spec exists** → investigate:
   - Read the user's request and relevant source files
   - Derive acceptance criteria
   - Present to user via AskUserQuestion for confirmation
   - Break into stories if multi-file; single story if atomic

   Do not ask the user to write a plan. Derive what you need.

## Phase 2: Per-Story Loop

```
For each story i/N:
  1. Record STORY_START_SHA = current HEAD
  2. Codex implements (MCP) → commit(s)
  3. Record STORY_HEAD_SHA = current HEAD
  4. Claude reviews (fresh Agent) → verdict
     PASS → step 5
     PASS_WITH_CONCERNS → record concerns → step 5
     FAIL → targeted fix (max 2 rounds) → re-review
  5. Record cross-story context → next story
```

### Step A: Implement

Record `STORY_START_SHA`:
```bash
git rev-parse HEAD
```

Dispatch Codex via MCP using the prompt template in `implementer-prompt.md`.
Fill all placeholders (story text, acceptance criteria, prior stories,
CODE_CONDUCT, TEST_CMD) before dispatch.

```
mcp__codex__codex({
  prompt: <filled implementer prompt>,
  sandbox: "workspace-write",
  approval-policy: "never",
  cwd: <repo root>
})
```

After Codex returns, save the `threadId` for potential targeted fixes.
1. Record `STORY_HEAD_SHA=$(git rev-parse HEAD)`
2. If `STORY_HEAD_SHA == STORY_START_SHA` and status is DONE → treat as
   BLOCKED (claimed done but made no commits).
3. If BLOCKED or NEEDS_CONTEXT → escalate to caller.
4. If DONE_WITH_CONCERNS → log concerns, proceed to review.
5. Otherwise → proceed to Step B.

### Step B: Review

Dispatch a fresh Claude Agent using the prompt template in `reviewer-prompt.md`.
Fill all placeholders (story number, SHAs, TEST_CMD, spec requirements,
story text) before dispatch.

After Reviewer returns, read the verdict:
- **PASS** → proceed to Step D.
- **PASS_WITH_CONCERNS** → append concerns to `concerns.md`. Proceed to Step D.
- **FAIL** → proceed to Step C. Max 2 rounds.
  If 2 rounds exhausted and still FAIL → escalate as BLOCKED.
- **No recognized verdict** → re-dispatch a fresh Reviewer once.
  If still unparseable → treat as FAIL.

### Step C: Targeted Fix

On FAIL, first verify repo state:

```bash
git rev-parse HEAD
git status --short
```

If uncommitted partial changes exist, stash or discard (warn the user).

Continue on the **same Codex thread** from Step A using `codex-reply`.
The implementer already has full context of what it built.

```
mcp__codex__codex-reply({
  threadId: <threadId from Step A>,
  prompt: "A code reviewer found these issues. Fix them.

    ## Issues to Fix
    <Reviewer's FAIL findings, verbatim>

    ## Rules
    - Fix ONLY the issues listed above. Do not refactor or improve other code.
    - Run the full test suite after fixes: <TEST_CMD>
    - If a fix requires a new test, add it.
    - Commit using Conventional Commits.
    Do NOT re-implement the story. Make surgical fixes."
})
```

After fix commits:
1. Update `STORY_HEAD_SHA=$(git rev-parse HEAD)`
2. Return to **Step B** with fresh Reviewer using updated commit range.

### Step D: Record Context

After each story completes (PASS or PASS_WITH_CONCERNS), record:

```
Story <i>: "<title>"
  Commits: <STORY_START_SHA>..<STORY_HEAD_SHA> (<N> commits)
  Files: <list of ALL files changed across all commits in range>
  Concerns: <any PASS_WITH_CONCERNS notes, or "none">
```

Use `git diff --name-only <STORY_START_SHA>..<STORY_HEAD_SHA>` to get
the complete file list. Pass this summary to the next story's prompt
in the "Prior Stories Completed" section.

## Phase 3: Cross-Story Regression

After all stories pass, dispatch Codex MCP to run the full test suite:

```
mcp__codex__codex({
  prompt: "Run the full test suite: <TEST_CMD>. Report PASS or FAIL with output.",
  sandbox: "workspace-write",
  approval-policy: "never",
  cwd: <repo root>
})
```

If tests fail, dispatch a targeted fix via Codex MCP and re-verify.

---

## Progress Reporting

Use `[Implement]` prefix for all status output:

```
[Implement] Starting — 5 stories, test cmd: make test
[Implement] Story 1/5: "Add user model" → implementing...
[Implement] Story 1/5: implemented (3 files, 1 commit). Reviewing...
[Implement] Story 1/5: PASS.
[Implement] Story 2/5: "Wire API endpoints" → implementing...
[Implement] Story 2/5: FAIL — missing input validation. Fixing (1/2)...
[Implement] Story 2/5: fix applied. Re-reviewing...
[Implement] Story 2/5: PASS (2 rounds).
...
[Implement] All 5 stories complete. 1 concern recorded.
```

## Artifacts

```text
.ship/tasks/<task_id>/
  concerns.md   — recorded PASS_WITH_CONCERNS notes (if any)
```

## Error Handling

| Condition | Action |
|-----------|--------|
| Reviewer FAIL, rounds < 2 | Targeted fix → fresh re-review |
| Reviewer FAIL, rounds exhausted | Escalate BLOCKED with findings |
| Reviewer malformed output | Re-dispatch fresh Reviewer once, then FAIL |
| Codex BLOCKED or NEEDS_CONTEXT | Escalate to caller |
| Codex DONE_WITH_CONCERNS | Log concerns, proceed to review |
| Codex crash (exit != 0) | Check HEAD + working tree; stash if dirty; retry once; then BLOCKED |
| Agent dispatch failure | Retry once, then BLOCKED |

## Completion

Report one of:
- **DONE** — all stories implemented, reviewed, committed.
- **DONE_WITH_CONCERNS** — all stories pass, concerns recorded.
- **BLOCKED** — a story failed after max retries.
- **NEEDS_CONTEXT** — missing information needed from user.

<Bad>
- Writing code yourself instead of dispatching Codex
- Reading the diff yourself instead of dispatching a fresh Agent reviewer
- Running tests yourself instead of letting Codex/reviewer handle it
- Falling back to "I'll just do it myself" when Codex is slow — report BLOCKED
- Skipping review because "Codex's self-review looked good"
- Starting the next story before the current story's review passes
- Running multiple implementation dispatches in parallel
- Doing a full re-implementation on FAIL instead of a targeted fix
- Letting Codex modify tests to make them pass instead of fixing code
- Accepting "close enough" on spec checklist — any FAIL item is FAIL
- Omitting prior stories context from the implementor prompt
- Retrying after crash without checking HEAD for partial changes
</Bad>
