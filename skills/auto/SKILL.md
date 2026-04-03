---
name: auto
version: 0.5.0
description: >
  Full pipeline orchestrator: design → dev → review → QA → simplify → handoff.
  Thin coordinator that delegates every phase to its skill and handles verdicts.
  Use when the task involves a scoped code change.
allowed-tools:
  - Bash
  - Read
  - Agent
  - AskUserQuestion
  - mcp__codex__codex
  - mcp__codex__codex-reply
---

## Preamble (run first)

```bash
SHIP_SKILL_NAME=auto source ${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Auto

Thin orchestrator that chains design → dev → review → QA →
simplify → handoff. Each phase is fully owned by its skill. Auto's
only job: call the skill, read the verdict, decide what's next.

## Core Principle

```
You dispatch Agent() calls and read their responses.
You may read code when needed (e.g. investigating NEEDS_CONTEXT).
You do NOT write code — all code changes go through subagents.
Allowed: git commands, mkdir, cat (for state file), Bash for coordination, Read for investigation.
```

## Process Flow

```dot
digraph auto {
    rankdir=TB;

    "Start" [shape=doublecircle];
    "Bootstrap" [shape=box];
    "Design (/ship:design)" [shape=box];
    "Dev (/ship:dev)" [shape=box];
    "Review (/ship:review)" [shape=box];
    "Review verdict?" [shape=diamond];
    "QA (/ship:qa)" [shape=box];
    "QA verdict?" [shape=diamond];
    "Simplify" [shape=box];
    "Simplify broke tests?" [shape=diamond];
    "Handoff (/ship:handoff)" [shape=box];
    "PR merge-ready" [shape=doublecircle];

    "Start" -> "Bootstrap";
    "Bootstrap" -> "Design (/ship:design)";
    "Design (/ship:design)" -> "Dev (/ship:dev)";
    "Dev (/ship:dev)" -> "Review (/ship:review)";
    "Review (/ship:review)" -> "Review verdict?";
    "Review verdict?" -> "Dev (/ship:dev)" [label="bugs, fix loop"];
    "Review verdict?" -> "QA (/ship:qa)" [label="clean"];
    "QA (/ship:qa)" -> "QA verdict?";
    "QA verdict?" -> "Dev (/ship:dev)" [label="FAIL, fix loop"];
    "QA verdict?" -> "Simplify" [label="PASS"];
    "Simplify" -> "Simplify broke tests?";
    "Simplify broke tests?" -> "Handoff (/ship:handoff)" [label="revert"];
    "Simplify broke tests?" -> "Handoff (/ship:handoff)" [label="clean"];
    "Handoff (/ship:handoff)" -> "PR merge-ready";
}
```

## Roles

| Role | Who |
|------|-----|
| Orchestrator | **You (Claude)** |
| Design | **/ship:design** — produces spec + plan |
| Dev | **/ship:dev** — implements stories, per-story review, cross-story regression |
| Code review | **/ship:review** — staff-engineer review of full diff |
| QA | **/ship:qa** — independent testing against running app |
| Simplify | **simplify** (standalone skill) — behavior-preserving cleanup |
| Handoff | **/ship:handoff** — PR creation, CI loop, proof bundle |

## Hard Rules

1. All code changes go through subagents. You may read code for investigation.
2. State file writes use Bash (`cat > file`). All other artifacts are produced by subagents.
3. Resume uses the `phase` field in the state file. No artifact guessing.
4. You own the decision loop — read Agent return, decide next action.
5. Report progress after every phase transition.
6. Never dispatch subagents in background.
7. Each skill owns its own intra-phase logic. Auto owns inter-phase flow and retry loops.

---

## Phase 1: Bootstrap

**State file:** `.ship/ship-auto.local.md`

### Step A: Check for active task

```
Read(".ship/ship-auto.local.md")
```

- **File exists** → read frontmatter. Extract `task_id`, `branch`, `base_branch`, `phase`. Jump to Step C (resume).
- **File does not exist** → proceed to Step B (new task).

### Step B: New task

Generate task ID:
```
Bash("${CLAUDE_PLUGIN_ROOT}/scripts/task-id.sh '<description>'")
```
Record as `TASK_ID`.

Create task directory:
```
Bash("mkdir -p .ship/tasks/<TASK_ID>")
```

Detect base branch:
```
Bash("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || (git rev-parse --verify origin/main >/dev/null 2>&1 && echo main || echo master)")
```
Record as `BASE_BRANCH`. Use this value in ALL later phases — never hardcode `main`.

Ensure we're on a feature branch — never work directly on `BASE_BRANCH`:
```
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "<BASE_BRANCH>" ]; then
  git checkout -b ship/<TASK_ID>
fi
BRANCH=$(git branch --show-current)
```

Write state file (via Bash):
```markdown
---
active: true
task_id: <TASK_ID>
session_id: ${CLAUDE_CODE_SESSION_ID}
branch: <BRANCH>
base_branch: <BASE_BRANCH>
phase: design
started_at: "<ISO 8601 timestamp>"
---

<original user description>
```

If `.ship/rules/CONVENTIONS.md` is missing: suggest `/ship:setup` but do not block.

Output: `[Ship] Task "<title>" created. Starting design phase...`

### Step C: Resume

Read `phase` from state file frontmatter → jump directly to that phase.

Update `session_id` in state file to current session (so this session owns the task).

Output: `[Ship] Resuming task "<task_id>" — phase: <phase>`

---

## Phase 2: Design

```
Agent(prompt="Call Skill('design').
  You are invoked by /ship:auto — do NOT ask the user questions. Treat
  any escalated items as BLOCKED and return.
  Task description: <description from state file body>
  task_id: <TASK_ID>
  Artifacts go to: .ship/tasks/<TASK_ID>/plan/
  Current branch: <BRANCH>
  HEAD SHA: <current HEAD>

  When done, end your response with:
  [RESULT]
  status: DONE|BLOCKED|NEEDS_CONTEXT
  detail: <one-line summary>
  artifacts: <files written>
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.
- `status: DONE` → proceed
- `status: BLOCKED` or `NEEDS_CONTEXT` → re-dispatch with more context (max 2 rounds)

**State update:** set `phase: dev` in `.ship/ship-auto.local.md`.

Output: `[Ship] Design complete — <N> stories identified. Starting dev...`

## Phase 3: Dev (ship:dev)

Record pre-dispatch HEAD SHA.

```
Agent(prompt="Call Skill('dev').
  You are invoked by /ship:auto — do NOT ask the user questions.
  If you cannot find TEST_CMD or need context, return NEEDS_CONTEXT.
  task_dir: .ship/tasks/<TASK_ID>
  spec: .ship/tasks/<TASK_ID>/plan/spec.md
  plan: .ship/tasks/<TASK_ID>/plan/plan.md
  base_branch: <BASE_BRANCH>

  When done, end your response with:
  [RESULT]
  status: DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT
  detail: <one-line summary, e.g. '4/4 stories complete, tests pass'>
  artifacts: <files written>
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.

| status | Action |
|--------|--------|
| DONE | proceed |
| DONE_WITH_CONCERNS | Log concerns from `detail`, proceed |
| BLOCKED | Read `detail`, re-dispatch with fix instructions (max 2) |
| NEEDS_CONTEXT | Read `detail` for what's missing, investigate, re-dispatch (max 2) |

**State update:** set `phase: review` in `.ship/ship-auto.local.md`.

Output: `[Ship] Dev complete. Starting review...`

## Phase 4: Review (ship:review)

```
Agent(prompt="Call Skill('review').
  You are invoked by /ship:auto (pipeline mode) — do NOT ask the user
  questions. If you cannot read the diff or spec, do a diff-only review.
  task_id: <TASK_ID>
  task_dir: .ship/tasks/<TASK_ID>
  spec: .ship/tasks/<TASK_ID>/plan/spec.md
  base_branch: <BASE_BRANCH>
  Write review to: .ship/tasks/<TASK_ID>/review.md

  When done, end your response with:
  [RESULT]
  status: DONE|BLOCKED
  detail: <e.g. 'No bugs found' or '3 bugs found: B1, B2, B3' or 'Cannot read diff'>
  artifacts: .ship/tasks/<TASK_ID>/review.md
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.

| status / detail | Action |
|-----------------|--------|
| DONE, no bugs found | proceed |
| DONE, N bugs found | enter review-fix loop (below) |
| BLOCKED | re-dispatch with adjusted context (max 2 rounds) |

### Review-fix loop

```
loop:
  1. Set phase: dev
  2. Dispatch ship:dev to fix the bugs (pass bug details from review Agent return):
     Agent(prompt="Call Skill('dev').
       You are invoked by /ship:auto — fix mode.
       These bugs were found by code review. Fix them.
       Bugs: <bug details from review Agent return>
       task_dir: .ship/tasks/<TASK_ID>
       spec: .ship/tasks/<TASK_ID>/plan/spec.md
       base_branch: <BASE_BRANCH>
       ...same [RESULT] contract...")
  3. Set phase: review
  4. Re-dispatch ship:review (same prompt as above)
  5. Read [RESULT]:
     - No bugs found → break, proceed
     - Bugs found → next round
```

**State update:** set `phase: qa` in `.ship/ship-auto.local.md`.

Output: `[Ship] Review clean. Starting QA...`

## Phase 5: QA (ship:qa)

```
Agent(prompt="Call Skill('qa').
  You are invoked by /ship:auto — do NOT ask the user questions.
  task_dir: .ship/tasks/<TASK_ID>
  spec: .ship/tasks/<TASK_ID>/plan/spec.md
  base_branch: <BASE_BRANCH>
  Write reports to: .ship/tasks/<TASK_ID>/qa/

  When done, end your response with:
  [RESULT]
  status: PASS|FAIL|SKIP|BLOCKED
  detail: <one-line summary, e.g. 'All 5 criteria pass' or 'App won't start: port 3000 in use'>
  artifacts: <report files written>
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.

| status | Action |
|--------|--------|
| PASS | proceed |
| SKIP (QA decided change doesn't need testing) | proceed |
| FAIL / BLOCKED | enter QA-fix loop (below) |

### QA-fix loop

```
loop:
  1. Set phase: dev
  2. Dispatch ship:dev to fix (pass issue details from QA Agent return):
     Agent(prompt="Call Skill('dev').
       You are invoked by /ship:auto — fix mode.
       QA found these issues. Fix them.
       Issues: <issue details from QA Agent return>
       task_dir: .ship/tasks/<TASK_ID>
       spec: .ship/tasks/<TASK_ID>/plan/spec.md
       base_branch: <BASE_BRANCH>
       ...same [RESULT] contract...")
  3. Set phase: qa
  4. Re-dispatch ship:qa with --recheck
  5. Read [RESULT]:
     - PASS/SKIP → break, proceed
     - FAIL/BLOCKED → next round
```

**State update:** set `phase: simplify` in `.ship/ship-auto.local.md`.

Output: `[Ship] QA passed. Running simplify...`

## Phase 6: Simplify

Record current HEAD before simplify:
```
Bash("git rev-parse HEAD")
```
Record as `PRE_SIMPLIFY_SHA`.

```
Agent(prompt="Call Skill('simplify').
  Scope: only files changed in this task (git diff <BASE_BRANCH>...HEAD --name-only).
  Output: .ship/tasks/<TASK_ID>/simplify.md

  When done, end your response with:
  [RESULT]
  status: DONE
  detail: <e.g. 'Simplified 3 functions' or 'Nothing to simplify'>
  artifacts: .ship/tasks/<TASK_ID>/simplify.md
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.
- Nothing changed → proceed.
- Code changed → verify simplify didn't break tests:
  ```
  Agent(prompt="Run the test command for this repo and report PASS or FAIL.
    When done, end with: [RESULT] status: PASS|FAIL [/RESULT]")
  ```
  - PASS → proceed.
  - FAIL → revert to `PRE_SIMPLIFY_SHA`, proceed anyway.

**State update:** set `phase: handoff` in `.ship/ship-auto.local.md`.

## Phase 7: Handoff (ship:handoff)

```
Agent(prompt="Call Skill('handoff').
  You are invoked by /ship:auto — do NOT ask the user questions
  task_id: <TASK_ID>
  task_dir: .ship/tasks/<TASK_ID>
  base_branch: <BASE_BRANCH>
  branch: <BRANCH>

  When done, end your response with:
  [RESULT]
  status: DONE|FAIL
  detail: <e.g. 'PR #42 merge-ready' or 'CI failing: test_auth'>
  artifacts: <PR URL>
  [/RESULT]")
```

**After return:** read `[RESULT]` from Agent response.

| status | Action |
|--------|--------|
| DONE | Extract PR URL from `artifacts`, done |
| FAIL | Re-dispatch handoff — it owns its own CI fix loop (max 2 rounds) |

**State update (DONE):** delete `.ship/ship-auto.local.md`.

Output: `[Ship] PR merge-ready: <url>`

---

## Example Workflow

```
── Phase 1: Bootstrap ─────────────────────────────────────

[Ship] Generating task ID...
  Bash("scripts/task-id.sh 'add dark mode toggle'")
  → TASK_ID = add-dark-mode-toggle

[Ship] Creating task directory...
  Bash("mkdir -p .ship/tasks/add-dark-mode-toggle")

[Ship] Detecting base branch...
  → BASE_BRANCH = main

[Ship] On main — creating feature branch...
  Bash("git checkout -b ship/add-dark-mode-toggle")
  → BRANCH = ship/add-dark-mode-toggle

[Ship] Writing state file...
  phase: design

[Ship] Task "add dark mode toggle" created. Starting design phase...

── Phase 2: Design ────────────────────────────────────────

[Ship] Dispatching /ship:design...
  Agent(prompt="Call Skill('design'). task_id: add-dark-mode-toggle ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: 3 stories identified — toggle component, CSS variables, persistence
  artifacts: .ship/tasks/add-dark-mode-toggle/plan/spec.md, plan.md
  [/RESULT]

[Ship] State update: phase → dev
[Ship] Design complete — 3 stories identified. Starting dev...

── Phase 3: Dev ───────────────────────────────────────────

[Ship] Recording HEAD SHA: abc1234
[Ship] Dispatching /ship:dev...
  Agent(prompt="Call Skill('dev'). task_dir: .ship/tasks/add-dark-mode-toggle ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: 3/3 stories complete, tests pass
  artifacts: src/components/ThemeToggle.tsx, src/styles/themes.css, src/hooks/useTheme.ts
  [/RESULT]

[Ship] State update: phase → review
[Ship] Dev complete. Starting review...

── Phase 4: Review ────────────────────────────────────────

[Ship] Dispatching /ship:review...
  Agent(prompt="Call Skill('review'). base_branch: main ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: 2 bugs found: B1 missing null check in useTheme, B2 CSS variable fallback
  artifacts: .ship/tasks/add-dark-mode-toggle/review.md
  [/RESULT]

[Ship] 2 bugs found. Entering review-fix loop...

[Ship] State update: phase → dev (fix mode)
[Ship] Dispatching /ship:dev to fix review bugs...
  Agent(prompt="Call Skill('dev'). fix mode. Bugs: B1, B2 ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: Fixed both bugs, tests pass
  [/RESULT]

[Ship] State update: phase → review
[Ship] Re-dispatching /ship:review...

  Agent returns:
  [RESULT]
  status: DONE
  detail: No bugs found
  artifacts: .ship/tasks/add-dark-mode-toggle/review.md
  [/RESULT]

[Ship] State update: phase → qa
[Ship] Review clean. Starting QA...

── Phase 5: QA ────────────────────────────────────────────

[Ship] Dispatching /ship:qa...
  Agent(prompt="Call Skill('qa'). base_branch: main ...")

  Agent returns:
  [RESULT]
  status: FAIL
  detail: Dark mode toggle doesn't persist after hard refresh (localStorage not set)
  artifacts: .ship/tasks/add-dark-mode-toggle/qa/browser-report.md
  [/RESULT]

[Ship] QA failed. Entering QA-fix loop...

[Ship] State update: phase → dev (fix mode)
[Ship] Dispatching /ship:dev to fix QA issues...
  Agent(prompt="Call Skill('dev'). fix mode.
    Issues: localStorage not set on toggle ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: Added localStorage.setItem in useTheme hook
  [/RESULT]

[Ship] State update: phase → qa
[Ship] Re-dispatching /ship:qa with --recheck...
  Agent(prompt="Call Skill('qa'). --recheck ...")

  Agent returns:
  [RESULT]
  status: PASS
  detail: All 4 criteria pass, toggle persists across hard refresh
  artifacts: .ship/tasks/add-dark-mode-toggle/qa/browser-report.md
  [/RESULT]

[Ship] State update: phase → simplify
[Ship] QA passed. Running simplify...

── Phase 6: Simplify ──────────────────────────────────────

[Ship] Recording PRE_SIMPLIFY_SHA: def5678
[Ship] Dispatching simplify...
  Agent(prompt="Call Skill('simplify'). Scope: git diff main...HEAD ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: Simplified useTheme hook — extracted shared logic
  artifacts: .ship/tasks/add-dark-mode-toggle/simplify.md
  [/RESULT]

[Ship] Simplify made changes. Running tests...
  Agent(prompt="Run npm test and report PASS or FAIL...")
  → PASS

[Ship] State update: phase → handoff

── Phase 7: Handoff ───────────────────────────────────────

[Ship] Dispatching /ship:handoff...
  Agent(prompt="Call Skill('handoff'). base_branch: main ...")

  Agent returns:
  [RESULT]
  status: DONE
  detail: PR #42 merge-ready
  artifacts: https://github.com/user/repo/pull/42
  [/RESULT]

[Ship] Deleting state file.
[Ship] PR merge-ready: https://github.com/user/repo/pull/42
```

### What This Shows

| Principle | How the example enforces it |
|-----------|---------------------------|
| **State file tracks phase** | Every phase transition updates the state file |
| **Agent return is the contract** | Orchestrator reads `[RESULT]` directly, no file parsing |
| **Fix loops go back to dev** | Review bugs → phase set to dev → dev fixes → phase set to review |
| **Simplify is safe** | SHA recorded before, tests run after, revert if broken |
| **No code writes** | Orchestrator dispatches Agents for all code changes |
| **Always ship** | Pipeline flows start to finish without stopping |

<Bad>
- Writing code yourself instead of delegating
- Hardcoding `main` instead of using BASE_BRANCH
- Giving up on a phase instead of fixing and retrying
- Dispatching subagents in background
</Bad>
