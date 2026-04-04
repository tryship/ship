---
name: dev
version: 0.5.0
description: Execute implementation stories from a plan via parallel waves. Dependency analysis groups independent stories into waves that run in parallel via git worktrees; each story is reviewed independently, and waves merge before proceeding.
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

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CODEX_HOME:-$HOME/.codex}/ship}}"
SHIP_SKILL_NAME=dev source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Implement

```
PEER IMPLEMENTS. FRESH REVIEWER DISCRIMINATES.
EVERY FINDING NEEDS FILE:LINE + EVIDENCE.
```

## Runtime Resolution

- **Host agent**: the provider currently running this skill
- **Peer agent**: the non-host provider when available; otherwise a
  fresh same-provider session

Resolve once at the start:
- Claude host → Codex is the peer implementer; Claude runs the fresh reviewer
- Codex host → Claude is the peer implementer; Codex runs the fresh reviewer
- If Claude is the peer, dispatch with `claude -p --permission-mode bypassPermissions`.
- If Codex is the peer, dispatch with `mcp__codex__codex`.
- If only one provider is available, use a fresh same-provider peer
  session and note that independence is weaker.

## Roles

| Role | Who |
|------|-----|
| Orchestrator | **You (host agent)** — coordinate stories, never write code |
| Implementor | **Peer agent** — fresh session per story |
| Reviewer | **Fresh Agent** — independent session per review |
| Targeted fixer | **Peer agent** — surgical fixes via same session |

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Spec + plan read | Acceptance criteria extracted, TEST_CMD found | AskUserQuestion |
| Implement → Review | STORY_HEAD_SHA != STORY_START_SHA (commits exist) | BLOCKED |
| Review → Next story | Verdict is PASS or PASS_WITH_CONCERNS | Targeted fix (max 2) |
| All stories → Done | Full test suite passes | Targeted fix for regression |

## Red Flag

**Never:**
- Write code, read diffs for review, or run tests yourself — only coordination metadata allowed
- Skip review for any story
- Parallelize stories that share files without dependency analysis
- Re-implement a full story on FAIL — use targeted fix instead
- Advance to next story without dispatching a reviewer Agent
- Let the peer modify tests to make them pass instead of fixing code
- Omit prior stories context from the implementer prompt
- Reuse a reviewer across stories — fresh Agent each time

---

## Phase 1: Setup

1. Read **acceptance criteria** (from spec file, or derived from user request).
2. Read **implementation stories** (from plan file, or single story for small tasks).
   Accept any heading format: `## Story N`, `## Step N`, `## N. Title`,
   or numbered/bulleted lists. Normalize as ordered stories.
3. Detect the repo's test command by inspecting project root
   (`Makefile`, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`,
   CI configs, `CLAUDE.md`/`AGENTS.md`). If none found, AskUserQuestion.
   Record as `TEST_CMD`.
4. Extract code conduct from `CLAUDE.md`, `AGENTS.md`, lint/formatter
   configs, and existing code patterns. Record as `CODE_CONDUCT`.
5. **Build story dependency graph.** For each story, identify:
   - Files/modules it will create or modify (from plan text)
   - Explicit dependencies (e.g., "uses the model from story 1")
   - Shared resources (e.g., two stories both modify the same config file)

   A story **depends on** another if it reads/imports what the other
   creates, or both modify the same file. Build a DAG and topologically
   sort into **waves** — groups of stories with no dependencies between
   them.

   ```
   Example: 5 stories
     Story 1: add User model          → no deps
     Story 2: add Product model       → no deps
     Story 3: add API for User        → depends on 1
     Story 4: add API for Product     → depends on 2
     Story 5: add auth middleware      → depends on 3, 4

   Waves:
     Wave 1: [Story 1, Story 2]       ← parallel
     Wave 2: [Story 3, Story 4]       ← parallel
     Wave 3: [Story 5]                ← sequential
   ```

   If the plan does not provide enough information to determine file
   overlap, default to **sequential** (single story per wave). Do not
   guess — false parallelism causes merge conflicts.

### Locating input

1. **Caller provides paths** → use them directly.
2. **Caller provides a task directory** → look for spec/plan files inside.
3. **No formal plan or spec exists** → derive acceptance criteria from
   user request + source files, confirm via AskUserQuestion, break into
   stories if multi-file. Do not ask the user to write a plan.

## Phase 2: Per-Wave Loop

For each wave, run all stories in the wave through Steps A→B→(C)→D.
- **Single-story wave**: run directly on the current branch.
- **Multi-story wave**: each story gets its own branch via git worktree.
  After all stories in the wave pass review, merge all branches back.

### Wave setup (multi-story waves only)

```bash
WAVE_BASE_SHA=$(git rev-parse HEAD)
# For each story in the wave:
git worktree add .ship/worktrees/story-<i> -b story-<i>
```

Each peer implementer receives `cwd: .ship/worktrees/story-<i>` (or the
absolute path) so it works in its own isolated copy.

### Wave merge (multi-story waves only)

After all stories in a wave pass review:

```bash
# For each story branch in the wave:
git merge story-<i> --no-edit
# If merge conflict → dispatch peer targeted fix to resolve, then retry
git worktree remove .ship/worktrees/story-<i>
git branch -d story-<i>
```

If a merge conflict cannot be resolved in 2 rounds → BLOCKED.

### Step A: Implement

Record `STORY_START_SHA`:
```bash
git rev-parse HEAD   # in the story's worktree for multi-story waves
```

Dispatch the peer implementer using the prompt template in
`implementer-prompt.md`. Fill all placeholders (story text, acceptance
criteria, prior stories, CODE_CONDUCT, TEST_CMD) before dispatch.
Use the dispatch pattern in `implementer-prompt.md` for the resolved
peer runtime. For multi-story waves, set `cwd` to the story's worktree.

For multi-story waves, dispatch all stories in the wave **in parallel**.

After the peer implementer returns, save the session id for targeted
fixes. For Codex peers, the `mcp__codex__codex` response includes a
`session_id` — store it as `PEER_SESSION_ID`.
1. Record `STORY_HEAD_SHA=$(git rev-parse HEAD)`
2. If `STORY_HEAD_SHA == STORY_START_SHA` and status is DONE → BLOCKED.
3. If BLOCKED or NEEDS_CONTEXT → escalate to caller.
4. If DONE_WITH_CONCERNS → log concerns.

Proceed to **Step B**. A story is only complete when review returns PASS.

### Step B: Review

Dispatch a fresh reviewer using the prompt template in
`reviewer-prompt.md`. Fill all placeholders (story number, SHAs,
TEST_CMD, spec requirements, story text) before dispatch.

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

Continue on the **same peer session** from Step A. The implementer
already has full context of what it built.

Build the targeted-fix prompt:

```
A code reviewer found these issues. Fix them.

## Issues to Fix
<Reviewer's FAIL findings, verbatim>

## Rules
- Fix ONLY the issues listed above. Do not refactor or improve other code.
- Run the full test suite after fixes: <TEST_CMD>
- If a fix requires a new test, add it.
- Commit using Conventional Commits.
- Do NOT re-implement the story. Make surgical fixes.
```

**Dispatch by peer runtime:**

- **Codex peer** — continue the session with `mcp__codex__codex-reply`:
  ```
  mcp__codex__codex-reply({
    session_id: <PEER_SESSION_ID from Step A>,
    reply: <targeted-fix prompt above>
  })
  ```
- **Claude peer** — `claude -p` cannot continue a session; re-dispatch a
  fresh session with the original story prompt **plus** the targeted-fix
  prompt appended.

If `mcp__codex__codex-reply` fails (e.g., session expired), fall back to
a fresh `mcp__codex__codex` dispatch with the original story prompt plus
the targeted-fix prompt.

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

After all stories pass, dispatch the peer implementer to run the full
test suite:

```
Run the full test suite: <TEST_CMD>. Report PASS or FAIL with output.
```

If tests fail, dispatch a targeted fix via the peer implementer and
re-verify. Max 2 rounds; then BLOCKED.

---

## Progress Reporting

Use `[Implement]` prefix:

```
[Implement] Starting — N stories in W waves, test cmd: <TEST_CMD>
[Implement] Wave w/W (parallel|sequential): Stories [list]
[Implement] Story i/N: "<title>" → implementing...
[Implement] Story i/N: PASS | FAIL — <detail>. Fixing (round/2)...
[Implement] Wave w/W: merging branches... ✓
[Implement] All N stories complete. M concerns recorded.
```

## Artifacts

```text
.ship/tasks/<task_id>/
  concerns.md   — recorded PASS_WITH_CONCERNS notes (if any)
```

## Example Workflow

```
[Implement] Starting — 5 stories, test cmd: npm test
[Implement] Dependency analysis:
  Wave 1: [Story 1 "Add User model", Story 2 "Add Product model"] ← parallel
  Wave 2: [Story 3 "User API", Story 4 "Product API"] ← parallel
  Wave 3: [Story 5 "Auth middleware"] ← sequential

═══ Wave 1 (parallel): Stories 1, 2 ════════════════════

[Implement] Wave 1: creating worktrees...
  git worktree add .ship/worktrees/story-1 -b story-1
  git worktree add .ship/worktrees/story-2 -b story-2
  WAVE_BASE_SHA = abc1234

[Implement] Story 1/5 + Story 2/5: dispatching peer implementers in parallel...
  Story 1 peer (cwd: .ship/worktrees/story-1) returns: DONE (PEER_SESSION_ID: session_s1)
  Story 2 peer (cwd: .ship/worktrees/story-2) returns: DONE (PEER_SESSION_ID: session_s2)

[Implement] Story 1/5: commits exist ✓ → dispatching fresh reviewer...
  Reviewer returns: PASS
[Implement] Story 2/5: commits exist ✓ → dispatching fresh reviewer...
  Reviewer returns: PASS

[Implement] Wave 1: all stories PASS. Merging branches...
  git merge story-1 --no-edit ✓
  git merge story-2 --no-edit ✓
  Cleaning up worktrees.

═══ Wave 2 (parallel): Stories 3, 4 ════════════════════

[Implement] Wave 2: creating worktrees...

[Implement] Story 3/5: dispatching peer implementer...
  Peer returns: DONE (PEER_SESSION_ID: session_s3)
[Implement] Story 4/5: dispatching peer implementer...
  Peer returns: DONE (PEER_SESSION_ID: session_s4)

[Implement] Story 3/5: reviewer returns FAIL
  - Missing input validation on POST /users
[Implement] Story 3/5: targeted fix (round 1/2)...
  mcp__codex__codex-reply({ session_id: session_s3, reply: <fix prompt> })
[Implement] Story 3/5: re-review → PASS (2 rounds).

[Implement] Story 4/5: reviewer returns PASS.

[Implement] Wave 2: merging branches... ✓

═══ Wave 3 (sequential): Story 5 ═══════════════════════

[Implement] Story 5/5: dispatching peer implementer...
  Peer returns: DONE_WITH_CONCERNS ("jwt secret hardcoded in test fixtures")
[Implement] Story 5/5: reviewer returns PASS_WITH_CONCERNS. Appending to concerns.md.

── Phase 3: Cross-Story Regression ──────────────────────

[Implement] Running full test suite...
  Peer returns: PASS (47 tests, 0 failures)

[Implement] DONE_WITH_CONCERNS — 5/5 stories, 3 waves, 1 concern recorded.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| Reviewer FAIL, rounds < 2 | Targeted fix → fresh re-review |
| Reviewer FAIL, rounds exhausted | Escalate BLOCKED with findings |
| Reviewer malformed output | Re-dispatch fresh Reviewer once, then FAIL |
| Peer implementer BLOCKED or NEEDS_CONTEXT | Escalate to caller |
| Peer implementer DONE_WITH_CONCERNS | Log concerns, proceed to review |
| Peer implementer crash (exit != 0) | Check HEAD + working tree; stash if dirty; retry once; then BLOCKED |
| Agent dispatch failure | Retry once, then BLOCKED |

## Execution Handoff

Output summary, then offer next steps in standalone mode:

```
[Implement] <DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT>
  Stories: <N>/<total> complete, <W> waves
  Concerns: <N> recorded in concerns.md
  Tests: <TEST_CMD> — <passed|failed>
  Files changed: <list>

## What's next?
1. **Review (recommended)** — run /ship:review to review the full diff
2. **QA** — run /ship:qa to test the running application
3. **Full pipeline** — run /ship:auto to review, QA, and ship
```

In /ship:auto mode, skip the "What's next?" choices and return — Auto owns the flow.

