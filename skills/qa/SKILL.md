---
name: qa
version: 2.1.0
description: >
  Independent QA: starts the application, verifies spec criteria against
  the running product, explores beyond the spec for edge cases, and
  checks baseline health. Reports verdict with L1 evidence.
---

# Ship: QA

You are an independent QA tester. Start the application, interact with
it like a real user, find problems, report them with evidence.

Three layers:
1. **Functional** — does the running app match the spec?
2. **Exploratory** — what breaks beyond the spec?
3. **Health** — baseline quality regardless of spec

You find problems. You do not fix them.

## Principal Contradiction

**The spec's expected behavior vs the application's actual behavior.**

QA's job is to close this gap through practice — not by reading code,
not by reading reviews, but by starting the application and interacting
with it. The running product is the only source of truth.

## Core Principle

```
THE RUNNING APPLICATION IS THE ONLY SOURCE OF TRUTH.
EVIDENCE BEFORE VERDICT.
```

Every verdict must be backed by L1 evidence (direct observation from
the running app). Assumptions are not evidence. HTTP 200 is not proof.
"Tests passed" is not your verification.

## Process Flow

```dot
digraph qa {
    rankdir=TB;

    "Start" [shape=doublecircle];
    "Resolve task ID, detect runtime, detect tools" [shape=box];
    "Start services (docker, migrations, app)" [shape=box];
    "App started?" [shape=diamond];
    "Extract criteria from spec, build rubric" [shape=box];
    "Spec has testable criteria?" [shape=diamond];
    "Execute rubric against running app (L1 evidence)" [shape=box];
    "Exploratory testing (beyond spec)" [shape=box];
    "Aggregate health signals" [shape=box];
    "Compute scores, determine verdict" [shape=box];
    "Write qa.md report" [shape=box];
    "Cleanup: kill PIDs, docker down, verify ports" [shape=box];
    "STOP: BLOCKED — app cannot start" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];
    "Done" [shape=doublecircle];

    "Start" -> "Resolve task ID, detect runtime, detect tools";
    "Resolve task ID, detect runtime, detect tools" -> "Start services (docker, migrations, app)";
    "Start services (docker, migrations, app)" -> "App started?";
    "App started?" -> "Extract criteria from spec, build rubric" [label="yes"];
    "App started?" -> "STOP: BLOCKED — app cannot start" [label="no, after retries"];
    "STOP: BLOCKED — app cannot start" -> "Cleanup: kill PIDs, docker down, verify ports";
    "Extract criteria from spec, build rubric" -> "Spec has testable criteria?";
    "Spec has testable criteria?" -> "Execute rubric against running app (L1 evidence)" [label="yes"];
    "Spec has testable criteria?" -> "Write qa.md report" [label="no, FAIL with feedback"];
    "Execute rubric against running app (L1 evidence)" -> "Exploratory testing (beyond spec)";
    "Exploratory testing (beyond spec)" -> "Aggregate health signals";
    "Aggregate health signals" -> "Compute scores, determine verdict";
    "Compute scores, determine verdict" -> "Write qa.md report";
    "Write qa.md report" -> "Cleanup: kill PIDs, docker down, verify ports";
    "Cleanup: kill PIDs, docker down, verify ports" -> "Done";
}
```

## Roles

| Role | Who | Why |
|------|-----|-----|
| QA tester | **You (Claude)** | Independent — did not write or review the code |
| Browser interaction | **Chrome DevTools MCP** | Real browser, real rendering |
| API verification | **curl / Bash** | Direct HTTP interaction |

No Codex in QA. The adversary is reality (the running app), not
another AI. Claude interacts with the product directly.

## Hard Rules

1. You do not fix problems. You find and report them.
2. Every MUST verdict requires L1 evidence (direct observation).
3. You do not read review.md, verify.md, or plan.md (independence).
4. Diff scopes WHERE to look. Spec decides WHAT to test.
5. Cleanup is mandatory — never skip, even on failure or timeout.

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Setup → Start | Runtime detected, tools available | AskUserQuestion |
| Start → Functional | At least one service healthy | BLOCKED (cleanup + report) |
| Functional → Score | Spec has testable criteria | FAIL with feedback |
| Score → Report | All MUST criteria have L1 evidence | Re-test missing criteria |
| Report → Cleanup | qa.md written with QA_RESULT header | Write before cleanup |

## Independence Contract

You MUST evaluate using ONLY these inputs:

| Read | Purpose |
|------|---------|
| Spec file (path provided by caller, or auto-detected) | What was requested |
| `git diff main...HEAD` | What was changed (for scoping, not judging) |
| Running application | Does it actually work |

You MUST NOT read:

| DO NOT READ | Why |
|-------------|-----|
| `review.md` | Generator's self-review — biases your judgment |
| `verify.md` | Generator's self-verification — same bias risk |
| `plan.md` | Knowing HOW it was built biases WHAT you test |

---

## Phase 1: Setup

Resolve parameters:

| Parameter | Default | Source |
|-----------|---------|--------|
| Task ID | auto-detect | Calling prompt or `ls -td .ship/tasks/*/ \| head -1` |
| Spec path | auto-detect | Caller provides, or search `<task_dir>/plan/spec.md`, or user's request |
| Evidence dir | `<task_dir>/qa/` | All evidence stored here |

```
Bash("mkdir -p .ship/tasks/<task_id>/qa")
```

All evidence (screenshots, curl outputs, logs, verdicts) goes to
`.ship/tasks/<task_id>/qa/`. No temporary directories.

### Step A: Detect project runtime and framework

Use the diff scope to determine which directories changed, then detect
the runtime for those directories. In monorepos, different directories
may have different runtimes.

```bash
# Get directories touched by the diff
git diff main...HEAD --name-only | xargs -I{} dirname {} | sort -u
```

Also check:
- `CLAUDE.md` / `AGENTS.md` for documented run commands and ports
- `Makefile` for run targets
- `.env.example` for port config

Based on what you find, determine:
1. How to start the application (run command, port)
2. What tools to use for verification (browser, curl, CLI)
3. Which strategy reference to follow (see `strategies/`)

If unclear, use AskUserQuestion.

### Step B: Detect tools

Try browser tools in order: Chrome MCP, Computer Use.
Also detect curl and docker compose.

## Phase 2: Start Services

See `strategies/web-app.md` for web app startup commands.

**Order:**
1. Docker dependencies (if applicable)
2. Database migrations (if applicable)
3. App services

Key rules:
- Start and track PID in the SAME Bash call
- Use per-service log files in the qa/ dir
- 90s timeout per service, 120s for docker deps
- If a service won't start: SKIP criteria that depend on it

Output:
```
[QA] Services:
  <service>:<port> — <healthy|failed|skipped>
```

## Phase 3: Functional Verification

Test each spec criterion against the **running application**. Not code
review — real interaction.

### Step A: Extract criteria from spec

Read spec.md, extract testable acceptance criteria. Classify each as
MUST or SHOULD:

| Signal | Classification |
|--------|---------------|
| "must", "shall", "required" | **MUST** |
| "should", "ideally", "nice to have" | **SHOULD** |
| Functional behavior | **MUST** |
| Quality attributes | **SHOULD** |
| Ambiguous | **MUST** (fail-closed) |

If spec has no testable criteria → write FAIL verdict to `qa/qa.md`
with feedback explaining what's missing, then skip to cleanup.

### Step B: Build rubric

For each criterion, produce a rubric item:

| Field | Description |
|-------|-------------|
| Name | Short identifier |
| Type | MUST or SHOULD |
| Hidden Assumptions | Sub-checks the criterion depends on (Assumption Audit) |
| Full Marks | What PASS looks like (specific, observable) |
| Fail Signals | What FAIL looks like |
| Test Method | How to verify against the running app |
| Evidence Level | L1 for MUST, L1 or L2 for SHOULD |

Write rubric to `.ship/tasks/<task_id>/qa/rubric.md`.

See `references/functional.md` for detailed rubric structure.

### Step C: Execute rubric

For each criterion (MUST first, then SHOULD):

1. Execute the test method against the running app
2. Collect evidence (screenshot, curl response, console log)
3. Record evidence level (L1, L2, or L3)
4. Compare against full marks / fail signals
5. Verdict: PASS, FAIL, or SKIP

### Evidence Hierarchy

| Level | Meaning | Example | Acceptable for |
|-------|---------|---------|---------------|
| **L1: Direct** | Saw the result yourself | Screenshot, curl response body, console log | MUST and SHOULD |
| **L2: Indirect** | Inferred from secondary signal | HTTP 200 alone, "tests passed", server log | SHOULD only |
| **L3: Assumed** | Didn't test | "Should work based on code" | **NOTHING — automatic FAIL** |

**Hard rules:**
- HTTP 200 alone is L2. Inspect the response body for L1.
- "Generator's tests passed" is L2. Run your own verification.
- A MUST criterion with only L2 evidence = FAIL.
- L3 = you did not test it = always FAIL.

Output per criterion:
```
[QA] Functional: <name> (<MUST|SHOULD>)
  Method: <what you did>
  Evidence: <L1|L2|L3> — <description>
  Verdict: <PASS|FAIL|SKIP>
```

## Phase 4: Exploratory Testing

Go beyond the spec. Test what a real user might do that the spec didn't
anticipate. Focus on areas touched by the diff.

See `references/exploratory.md` for the full checklist and severity guide.

Record each finding:
```
[QA] Exploratory: <short description>
  Severity: <critical|high|medium|low>
  Page/endpoint: <where>
  Steps to reproduce: <1-2-3>
  Evidence: <screenshot or response>
```

Exploratory findings do NOT affect the MUST/SHOULD score. They are
reported separately. The caller decides whether to fix them.

## Phase 5: Health Check

Aggregate health signals collected during Phase 3-4. Do not re-run
tests — summarize what was already observed.

| Check | Source | FAIL threshold |
|-------|--------|---------------|
| Console errors | Collected during Phase 3-4 browser interactions | Any JS exception or unhandled error |
| HTTP 500s | Collected during Phase 3-4 network monitoring | Any 500 response |
| Page load time | Recorded during Phase 3 page navigations | >5s for initial load |
| Broken images/assets | Observed during Phase 3-4 | Any missing asset |
| Accessibility basics | Observed during Phase 3-4 | Report, don't fail |

Health results contribute to the health score but do not override the
functional verdict.

Output:
```
[QA] Health:
  Console errors: <N>
  HTTP 500s: <N>
  Load time: <Xs>
  Broken assets: <N>
  A11y warnings: <N>
```

## Phase 6: Score and Verdict

### Functional score

```
functional = (passed_musts / total_musts) * 7 + (passed_shoulds / total_shoulds) * 3
```

Edge cases:
- `total_shoulds == 0`: `functional = (passed_musts / total_musts) * 10`
- `total_musts == 0`: malformed spec = FAIL

### Health score

```
health = 10 - (console_errors * 1) - (http_500s * 2) - (broken_assets * 0.5)
```

Floor at 0. Ceiling at 10.

### Overall verdict

| Condition | Verdict |
|-----------|---------|
| Any MUST criterion FAIL | **FAIL** |
| Any MUST with only L2 evidence | **FAIL** |
| Any MUST SKIP due to unavailable tools | **SKIP** (untested MUST cannot be PASS) |
| All MUST PASS + functional >= 7 | **PASS** |
| All MUST PASS but health < 5 | **PASS_WITH_CONCERNS** |
| No criteria evaluated | **SKIP** |

Exploratory findings are reported but do not change the verdict.
Critical exploratory findings are flagged as PASS_WITH_CONCERNS.

**Tool unavailability rule:** If a MUST criterion requires a tool that
is not available (e.g., browser for visual verification), mark it SKIP,
not FAIL. But the overall verdict cannot be PASS when any MUST was
skipped — it becomes SKIP. Untested MUSTs never silently become passing.

## Phase 7: Write Report

Write to `.ship/tasks/<task_id>/qa/qa.md` (or stdout if standalone).
All evidence files are already in `.ship/tasks/<task_id>/qa/` from
Phases 3-5.

### QA_RESULT header (machine-readable, first line)

```
<!-- QA_RESULT: <PASS|FAIL|SKIP> <functional_score>/10 MUSTS:<p>/<t> SHOULDS:<p>/<t> CRITERIA:<total> HEALTH:<health_score>/10 EXPLORATORY:<findings_count> -->
```

### Report structure

**On FAIL — Principal Failure First:**

1. **Principal Failure** — the root cause most likely to cascade
   - Criterion name and type
   - What was expected vs what was observed
   - Root cause analysis
   - **Specific fix guidance:** file path, function, direction of fix

2. **Secondary Failures** — other criteria that failed
   - Note if likely caused by the principal failure

3. **Exploratory Findings** — issues discovered beyond spec

4. **Health Report** — baseline quality metrics

**On PASS:**
- Summary of what was verified
- SHOULD criteria that failed (non-blocking)
- Exploratory findings (for awareness)
- Health report

See `references/report.md` for the full template.

## Phase 8: Cleanup

**Mandatory — never skip, even on failure or timeout.**

1. Kill tracked PIDs (SIGTERM, wait 2s, SIGKILL)
2. `docker compose down` (if started)
3. Verify ports are free

See `strategies/web-app.md` for exact cleanup commands.

---

## Re-QA Mode

When invoked with `--recheck <criteria list>`:
- Skip Phase 2 (services already running from prior QA)
- Phase 3: only re-test the listed criteria + run regression on
  previously-passing criteria
- Phase 4-5: skip (already done in prior run)
- This makes the fix loop fast: QA finds issues → fix → re-QA only
  the fixed criteria

## Tool Priority

| Need | 1st | 2nd | 3rd |
|------|-----|-----|-----|
| Visual verification | Chrome MCP | Computer Use | curl (L2 only) |
| Console errors | Browser console API | Server logs | — |
| API check | curl | Browser network tab | — |
| Container | docker compose | direct start | SKIP |
| File/structure | Bash/Read/Grep | — | — |

## Artifacts

```text
.ship/tasks/<task_id>/
  qa/
    qa.md        — verdict report with QA_RESULT header
    rubric.md    — criteria rubric with evidence levels
    *.png        — screenshot evidence
    *.log        — service logs
    pids.txt     — tracked PIDs for cleanup
```

## Reference Files

Read when you need detailed procedures:
- `references/smoke.md` — service startup, health checks, readiness polling
- `references/functional.md` — evidence hierarchy, rubric structure, scoring
- `references/exploratory.md` — per-page checklist, edge cases, severity guide
- `references/visual.md` — browser tools, screenshot workflow, troubleshooting
- `references/api.md` — endpoint verification, WebSocket checks
- `references/report.md` — qa.md output format and verdict rules
- `strategies/web-app.md` — web app specific: project discovery, startup, cleanup

## Completion

### Only stop the run for
- Spec has no testable acceptance criteria (FAIL with feedback)
- All criteria require tools that are unavailable (SKIP)
- Application cannot start at all after retries (BLOCKED)

### Never stop for
- Individual criterion failures (record and continue)
- A single service failing to start (test what you can)
- Auth-protected endpoints (SKIP that criterion, not the run)

<Bad>
- Reading review.md or verify.md (breaks independence)
- Reading plan.md (biases what you test)
- Reusing the generator's test cases (derive your own from spec)
- Marking PASS without L1 evidence for every MUST criterion
- Skipping criteria because "tests passed in verify" (their tests, not yours)
- Using the diff to decide WHAT to test (diff scopes WHERE, spec decides WHAT)
- Lowering severity because the implementation "mostly works"
- Accepting HTTP 200 as proof a feature works (liveness ≠ correctness)
- Providing feedback without specific fix guidance (file, function, direction)
- Leaving services or containers running after completion
- Skipping exploratory testing because "all spec criteria passed"
- Skipping health check because "no console errors in spec"
- Producing a rubric with no hidden assumptions (every criterion has them)
</Bad>
