# Skill Deep Dives

Detailed guides for every Ship skill — philosophy, workflow, and examples.

| Skill | Role | What it does |
|-------|------|--------------|
| [`/ship:auto`](#auto) | **Pipeline Orchestrator** | The full pipeline. One command from task description to a PR with checks green. Delegates every phase to fresh subagents with quality gates at every transition. Fully autonomous — no approval gates. |
| [`/ship:design`](#design) | **Adversarial Designer** | The host agent and a peer agent independently investigate the codebase and produce specs in parallel. Divergences are resolved by code evidence and debate. The merged spec feeds an executable TDD plan validated by a peer drill. |
| [`/ship:dev`](#dev) | **Implementation Engine** | Executes stories from a plan via parallel waves. Dependency analysis groups independent stories; within each wave stories run in parallel via git worktrees, each reviewed independently, then merged before the next wave. |
| [`/ship:review`](#review) | **Staff Engineer** | Find every bug in the diff, then diagnose the structural deficiency that breeds them. Bugs are symptoms — the structural crack is the disease. |
| [`/ship:qa`](#qa) | **Independent QA** | Starts your app, tests every acceptance criterion against the running product. Independence contract: cannot read the review or plan. Only direct observation counts. |
| [`/ship:handoff`](#handoff) | **Release Engineer** | Creates a PR with a concise verification summary, then enters the fix loop: GitHub check failures, review comments, merge conflicts. Doesn't stop until the PR checks are green or retries are exhausted. |
| [`/ship:refactor`](#refactor) | **Structural Diagnostician** | Traces from concrete pain to structural cracks. Diagnoses and fixes directly — surgical (within-file) or structural (cross-file) execution. |
| [`/ship:setup`](#setup) | **Repo Bootstrapper** | Detects stack, installs tools, configures CI/CD and pre-commit hooks, discovers semantic constraints from code and git history, generates AGENTS.md + .learnings/LEARNINGS.md + hookify safety rules. Audits existing harness for staleness. |
| [`/ship:learn`](#learn) | **Session Learner** | Captures mistakes and discoveries from sessions into `.learnings/LEARNINGS.md`. Auto-verifies durable entries and prunes stale ones. |
| [`/ship:write-design-docs`](#write-design-docs) | **Design Doc Author** | Creates and maintains high-level design documents with structured frontmatter for AI indexing, status lifecycle, and verification against code. |

---

## `auto`

This is the **full pipeline**.

You describe what you want to build. Ship handles the rest — plan, implement, review, verify, QA, simplify, handoff — with quality gates at every transition.

### Why an orchestrator?

AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

The orchestrator delegates all code changes to fresh subagents. It may read code when investigating issues (e.g. NEEDS_CONTEXT from dev), but never writes code itself. State is tracked in `.ship/ship-auto.local.md` — the stop-gate hook prevents exit while the pipeline is active.

### The independence architecture

Implementation and review use **separate runtimes**. Cross-provider separation is preferred when available because model biases differ as well as session context. When only one provider is available, Ship still uses fresh same-provider sessions so review does not collapse into self-review.

The QA evaluator is contractually forbidden from reading the review or the plan. It can only look at the spec and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

### Seven phases

```
Bootstrap → Design → Dev → Review → QA → Simplify → Handoff
```

1. **Bootstrap** — init task directory, detect base branch, create feature branch, write state file
2. **Design** — invoke `/ship:design` for adversarial planning
3. **Dev** — invoke `/ship:dev` to execute implementation stories
4. **Review** — invoke `/ship:review` for staff-engineer code review
5. **QA** — invoke `/ship:qa` against the running application
6. **Simplify** — behavior-preserving cleanup via standalone simplify skill
7. **Handoff** — invoke `/ship:handoff` to create PR and shepherd it until checks are green

Review and QA have fix loops: if bugs/issues are found, auto dispatches dev to fix them, then re-runs the phase. No phase is ever skipped.

### State lives on disk

The current phase is tracked in `.ship/ship-auto.local.md` — a YAML frontmatter file with task_id, branch, base_branch, and phase. The stop-gate hook reads this file and blocks session exit while the pipeline is active. On resume, auto reads the phase field and jumps directly to that phase.

### Example

```
You:   Add rate limiting to the /api/upload endpoint

Assistant: [Ship] Bootstrapping task: rate-limit-upload
        [Ship] Phase 2: Design — investigating codebase...

        [Design] Read src/routes/api/upload.ts, traced to middleware chain...
        [Design] Found existing rate limiter in src/middleware/rateLimit.ts
               but /api/upload bypasses it (line 42, direct route mount).
        [Design] Peer challenger confirmed: both plans agree on middleware approach.
        [Design] Execution drill passed — 3 stories, all implementable.

        [Ship] Design complete — 3 stories extracted.

        ┌─ Spec: rate-limit-upload ─────────────────────────┐
        │ Story 1: Wire /api/upload through existing rate    │
        │          limiter middleware                         │
        │ Story 2: Add per-user upload quota (100/hour)      │
        │ Story 3: Return 429 with Retry-After header        │
        │                                                    │
        │ Acceptance criteria:                               │
        │ - MUST: 429 response after 100 uploads/hour/user   │
        │ - MUST: Retry-After header present in 429          │
        │ - SHOULD: Existing rate limiter tests still pass   │
        └───────────────────────────────────────────────────┘

        [Ship] Dev: Implementing 3 stories...
        [Dev] Story 1: PASS — middleware wired, tests green
        [Dev] Story 2: PASS — quota logic added with Redis counter
        [Dev] Story 3: PASS — 429 + Retry-After verified

        [Ship] Review: Code review...
        [Review] 1 finding: Redis key missing TTL
        [Ship] Dev: Fixing review bugs...
        [Ship] Review: Re-reviewing... clean.

        [Ship] QA: Testing against running app...
        [QA] 3/3 MUST criteria passed (L1 evidence: curl responses)
        [QA] Verdict: PASS

        [Ship] Simplify: No dead code found.

        [Ship] Handoff: Creating PR...
        PR #48 created. CI passing. Ready for review.
```

One command. Task description to a PR with checks green. Fully autonomous.

---

## `design`

This is where **adversarial rigor** meets planning.

Most AI planning is a monologue. The model reads your request, skims the codebase, and writes a plan that sounds reasonable. The problem: "sounds reasonable" is not "survives contact with reality." Plans fail when they reference files that don't exist, assume APIs that have different signatures, or miss existing defenses that already handle the case.

### How it works

Two phases produce two artifacts:

**Phase 1: Design** — the host agent and a peer agent independently investigate the codebase using identical methodology and produce separate specs. The peer is dispatched first, then the host investigates in parallel. Neither sees the other's spec. Divergences are resolved by code evidence, and when evidence alone isn't conclusive, by debate (max 2 rounds on the peer thread/session, both sides cite file:line).

The merged spec follows brainstorming style — flexible sections scaled to complexity. A small bugfix gets a few paragraphs. An architectural change gets full sections.

**Phase 2: Write Plan** — The validated spec feeds an executable plan in writing-plans format: bite-sized TDD tasks with checkbox steps, complete code blocks, exact commands, no placeholders. The peer agent validates the plan via execution drill — checking format compliance, file path existence, and spec coverage.

### The adversarial loop

This is not a review. It is two independent investigations of the same problem by separate runtimes, ideally on different providers.

- **Specs diverge** → resolution by code evidence first. If still unresolved, debate with the peer agent on the same thread/session when possible (max 2 rounds, both sides cite file:line). Dispositions: patched, proven-false, conceded, or escalated to user.
- **Debate exhausted** → escalated items go to the user in standalone mode, or block in auto mode.

### The execution drill

The final gate: the peer agent reads the plan and checks every task for implementability. Format compliance (TDD order, checkboxes, no placeholders), file path verification (Create paths don't exist, Modify paths do), and spec coverage (every acceptance criterion has a task).

Tasks flagged UNCLEAR get revised and re-drilled once. Plans that survive are implementable.

### Example

```
You:   Design adding WebSocket support for real-time notifications

Assistant: [Design] Dispatching peer investigation...
        [Design] Investigating codebase...
        Read src/server.ts — Express app, no existing WS setup.
        Read src/routes/notifications.ts — polling endpoint, 5s interval.
        Read src/services/notificationService.ts — pushes to Redis pub/sub.
        Read package.json — no ws/socket.io dependency.

        [Design] Writing spec.md...

        [Design] Reading peer spec...
        [Design] Diffing specs...

        DIVERGENCE: Host spec modifies server.ts directly.
                    Peer spec creates separate ws-server.ts.
                    → Code evidence: server.ts:14 already has upgrade
                      handler for health checks. Peer is right.
                    → Disposition: conceded. spec.md updated.

        [Design] Writing plan.md (3 TDD tasks)...
        [Design] Execution drill...
        Peer flagged: "Task 2 Step 1 test references NotificationType
        but doesn't specify which file." → UNCLEAR
        → Revised: added src/types/notification.ts:8. Re-drilled: CLEAR.

        Design complete. spec.md + plan.md ready.
```

---

## `dev`

This is the **implementation engine**.

The key insight is role separation: **the peer implements, the fresh reviewer discriminates.** The peer implementer handles each story in an isolated session. A fresh reviewer — ideally on the other provider — checks spec compliance and code correctness independently.

### Waves and dependency analysis

Stories are analyzed for dependencies (shared files, import chains) and grouped into **waves**. Independent stories within a wave run **in parallel** via git worktrees; waves run sequentially.

1. **Build dependency graph** — identify which stories create, modify, or import the same files
2. **Sort into waves** — topological sort into groups with no intra-group dependencies
3. **Per wave** — create worktrees, dispatch peer implementers in parallel, review each independently
4. **Wave merge** — merge all story branches back after review passes
5. **Cross-story regression** — full test suite after all waves complete

If FAIL → targeted fix (max 2 rounds), not a full rewrite.

### Example

```
You:   /ship:dev

Assistant: [Dev] Reading plan: 3 stories for rate-limit-upload

        [Dev] Dependency analysis: 2 waves
              Wave 1: [Story 1, Story 2] ← parallel (no shared files)
              Wave 2: [Story 3] ← depends on Story 1

        [Dev] Wave 1: creating worktrees, dispatching in parallel...
        [Peer] Story 1: Wire /api/upload through rate limiter... done
        [Peer] Story 2: Add per-user upload quota... done
        [Review] Story 1: PASS
        [Review] Story 2: FAIL — Redis key uses IP instead of user ID
        [Dev] Story 2: targeted fix round 1...
        [Review] Story 2: PASS
        [Dev] Wave 1: merging branches... clean.

        [Dev] Wave 2: Story 3 (sequential)
        [Peer] Return 429 with Retry-After header... done
        [Review] PASS

        [Dev] Cross-story regression: all tests green.
        [Dev] 3/3 stories, 2 waves complete.
```

---

## `review`

This is the **staff engineer who finds the disease, not just the symptoms**.

Code review has two jobs:

1. **Find every bug.** The class of bugs that survive CI but explode in production: N+1 queries, race conditions, trust boundary violations, missing error handling on partial failures, tests that test the wrong thing, forgotten enum handlers when new values are added. All of them, with file:line + triggering scenario.

2. **Diagnose the structural deficiency.** Bugs cluster around structural weaknesses — a missing validation boundary, shared mutable state without ownership, a trust boundary in the wrong layer. The review identifies the ONE structural crack that breeds the bug cluster. Fix the crack, and a class of bugs disappears — not just the ones caught today, but the ones that would have appeared in the next PR.

This is the principal contradiction applied to code review: bugs are the many contradictions, and the structural deficiency is the principal contradiction whose existence determines the others.

---

## `qa`

This is **independent QA**.

The most important word is "independent." The QA evaluator is contractually forbidden from reading the review, the verification results, or the plan. It can only look at two things: the spec (what was supposed to be built) and the running application (what was actually built). This independence contract exists because every other phase has optimistic bias — the implementer thinks their code works, the reviewer saw the implementation context, the verifier ran the tests the implementer wrote. QA is the outsider.

### Evidence hierarchy

Every verdict must be backed by direct evidence — screenshots, curl responses, command output. "Should work based on code" is not evidence. HTTP 200 alone is not proof — inspect the response body.

### How it works

QA reads the spec and the git diff, then matches testing to what changed:

- **Frontend changes** → browser testing (via agent-browser)
- **API changes** → endpoint testing (via curl)
- **CLI changes** → terminal testing

Most projects have a frontend. When you test through the browser, you implicitly test the API, auth, database, and most of the stack.

### Example

```
You:   /ship:qa

Assistant: [QA] Reading spec and diff...
        [QA] Diff touches: src/api/rate-limit.ts, src/components/UploadForm.tsx
        [QA] Starting application... server ready on :3000

        [QA] Testing spec criteria:
        Rate limit at 100 uploads/hour — PASS
          curl: POST /api/upload x101, 101st returns 429 {"error":"rate limited"}
        Retry-After header present — PASS
          curl: Retry-After: 3600 in 429 response
        Non-upload endpoints unaffected — PASS
          curl: GET /api/status returns 200 during rate limit

        [QA] Beyond spec:
        - Concurrent uploads from same user: rate limit triggers correctly
        - Unauthenticated requests: returns 401 before rate limit check
        - Edge: 100th request returns 200, 101st returns 429

        Verdict: PASS — all spec criteria met, no issues found
```

---

## `handoff`

This is the **last mile**.

Most branches die after the interesting work is done. The code works, the tests pass, but the PR never gets created — or it gets created and then CI fails and nobody fixes it. Handoff exists to close that gap.

### The PR summary

Handoff doesn't just create a PR. It carries the minimum useful verification summary.

Every PR body should say:

- what changed
- what local verification ran
- any known follow-up, risk, or skipped check

### The fix loop

After creating the PR, handoff enters a loop:

1. Wait for CI
2. If CI fails → read logs, dispatch fix, re-push
3. If review comments → mechanical fixes auto-addressed, judgment calls escalated
4. If merge conflicts → auto-resolve, re-verify

Max 3 rounds. If it can't get the PR checks green in 3 rounds, it escalates to you with a clear explanation of what's blocking.

### Harness freshness check

Before declaring the PR ready, handoff verifies that harness docs (AGENTS.md, .learnings/LEARNINGS.md, README.md) still match the code. Stale documentation is treated as a PR-blocking finding — not background noise.

### What it won't do

- Never force push
- Never skip tests
- Never auto-merge (creates the PR, doesn't merge it)
- Never address security or architecture review comments without asking you

### Example

```
You:   /ship:handoff

Assistant: [Handoff] Checking proof freshness...
        Tests: PASS at a1b2c3d (current HEAD) ✓
        Lint: PASS at a1b2c3d ✓
        QA: PASS at a1b2c3d ✓

        [Handoff] Merging main into feature branch... clean.
        [Handoff] Creating PR #48...

        [Handoff] Waiting for CI...
        CI: 3/3 checks passed ✓

        [Handoff] PR #48 checks are green.
        https://github.com/yourorg/yourrepo/pull/48
```

---

## `refactor`

This is the **structural diagnostician**.

Refactoring is not "clean up the code." It's answering: **why does adding a feature feel harder than it should?**

### Trace from pain, not from structure

Bad refactoring starts with "this module is too big" or "we should use the repository pattern." Good refactoring starts with a specific pain: "every time we add a new notification type, we have to change 4 files." That pain traces to a structural crack — a boundary that doesn't match how the code is actually used.

`refactor` traces from the concrete pain to the crack:

1. **Start with the painful change** — what specific thing is hard to do?
2. **Trace the dependency chain** — why does this change touch so many files?
3. **Find the crack** — which boundary is misaligned with usage?
4. **Validate with counterfactual** — if we fixed this crack, would the painful change become simple?
5. **Check git history** — is this a one-off or a pattern? (`git log --all --oneline -- <file>`)

### Diagnosis depth matches input

- **Directive** ("extract this into a module") → light validation, then execute
- **Area** ("refactor the auth system") → medium diagnosis, then spec
- **Pain** ("adding notifications is painful") → full diagnosis from pain to crack
- **Vague** ("something feels wrong in this codebase") → full diagnosis, widest search

### What it produces

Code changes, not documents. Diagnoses the pain, traces to the structural crack, then fixes directly. Surgical execution for within-file smells, structural execution (with an execution card) for cross-file issues.

### Example

```
You:   Every time I add a new payment provider, I have to change 6 files.

Assistant: [Refactor] Tracing from pain...
        Read src/payments/stripe.ts, src/payments/paypal.ts
        Read src/routes/checkout.ts — switch statement on provider type (line 84)
        Read src/services/billing.ts — another switch (line 112)
        Read src/types/payment.ts — union type (line 23)
        Read tests/payments.test.ts — duplicated test setup per provider

        [Refactor] Found the crack:
        Payment providers are scattered across a type union, two switch
        statements, and duplicated test setup. Adding a provider means
        updating all four locations plus the route handler.

        The boundary should be: one file per provider that implements
        a common interface. The switch statements become a registry lookup.

        [Refactor] Git history confirms pattern:
        - 4 PRs in last 3 months each touched all 6 files
        - Average PR size for "add provider": 340 lines (should be ~80)

        [Refactor] Counterfactual:
        With a provider interface + registry, adding a provider is:
        1 new file implementing the interface, 1 line registering it.

        Spec written to .ship/tasks/refactor-payments/plan/spec.md
        Handing off to auto...
```

---

## `setup`

This is the **repo bootstrapper**.

New repo? Inherited codebase? Missing linter? No CI? `setup` handles all of it — and then discovers semantic constraints that AI agents would violate without project context.

### Infrastructure

Detects languages (15 supported including Shell), package managers, linters, formatters, type checkers, test runners, CI/CD, and pre-commit hooks. You pick which modules to configure. It respects existing config — if you already have husky or `.pre-commit-config.yaml` working, it won't migrate.

### Harness

Investigates code and git history for two types of rules:

- **Semantic rules** (.learnings/LEARNINGS.md) — things only AI can judge: "don't remove auth to fix errors", "price is in cents not dollars", "legacy module is being migrated". Injected into every session via SessionStart hook.
- **Safety rules** (hookify) — deterministic regex checks: block editing .env files, block DROP TABLE. Real-time PreToolUse blocking.

If harness files already exist (AGENTS.md, CLAUDE.md, .learnings/LEARNINGS.md), setup audits them for staleness before generating.

### Three-layer defense

| Layer | Tool | How | Cost |
|-------|------|-----|------|
| Real-time block | Hookify rules | regex on PreToolUse | Free |
| Semantic context | .learnings/LEARNINGS.md | SessionStart injection | Free |
| Commit-time | Pre-commit hook | lint + format | Free |

### Example

```
You:   /ship:setup

Assistant: [Setup] Detecting stack...
        TypeScript (pnpm)
        Linter: oxlint (ready)
        Formatter: prettier (ready)
        Test runner: vitest (ready)
        Pre-commit: lint-staged configured, no hook runner ⚠

        [Setup] Wiring lint-staged via core.hooksPath...

        [Setup] Investigating constraints...
        Git history: 1 revert (notebook metadata), 12 bug fixes
        Code: auth flow in src/auth/, no obvious semantic traps

        SAFETY RULES (hookify):
          ✓ [D1] Block .env file edits

        SEMANTIC RULES (.learnings/LEARNINGS.md):
          ✓ [S1] Don't remove auth checks to fix errors
              Why: AI agents delete validation to make errors go away

        [Setup] Complete.

        AGENTS.md: generated
        .learnings/LEARNINGS.md: 1 semantic rule
        Hookify: 1 safety rule
        Pre-commit: wired via core.hooksPath
```

---

## `learn`

This is the **self-improving harness**.

Every session produces knowledge — mistakes made, surprises discovered, project quirks found. Without capture, the next session starts from scratch. `/ship:learn` captures that knowledge and routes it to the right persistent store.

### Fully autonomous

No user interaction. The skill reflects on the session, classifies each learning, and writes it to the correct store:

| Learning type | Destination |
|---|---|
| Code constraint requiring AI judgment | .learnings/LEARNINGS.md |
| Deterministic check (grep/regex can catch) | Hookify rule |
| Architectural decision or boundary | Design doc |
| Operational knowledge | `.learnings/LEARNINGS.md` (staging) |

### Staging lifecycle

`.learnings/LEARNINGS.md` is a staging area, not a permanent store. Learnings that prove durable (repeated, aged + still valid) get auto-promoted to permanent stores. Learnings that go stale (scope deleted, already covered, contradicted) get auto-pruned. The staging file stays lean.

### Three layers of harness memory

All injected at session start:

1. **.learnings/LEARNINGS.md** — code-level guardrails
2. **DESIGN_INDEX.md** — architecture-level guardrails
3. **LEARNINGS.md** — operational knowledge from recent sessions

---

## `write-design-docs`

This is **architectural guardrails for AI and humans**.

Design docs prevent the most dangerous form of AI drift: locally-correct decisions that violate the overall architecture. Without design docs, an AI might merge services that must stay separate or simplify flows with hidden constraints.

### Structured for AI indexing

Every design doc has YAML frontmatter with fields designed for machine consumption:

- **description** — one sentence for AI relevance filtering
- **status** — trust signal (current, draft, partially-outdated, superseded, not-implemented)
- **services** — which directories this design covers
- **last_verified** — when the doc was last checked against code

### Index injection

`generate-design-index.sh` builds a compact table from all design doc frontmatter. `session-start.sh` injects this table at session start, so AI agents know what design docs exist without reading each one.
