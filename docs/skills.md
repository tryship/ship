# Skill Deep Dives

Detailed guides for every Ship skill — philosophy, workflow, and examples.

| Skill | Role | What it does |
|-------|------|--------------|
| [`/ship:auto`](#auto) | **Pipeline Orchestrator** | The full pipeline. One command from task description to merge-ready PR. Delegates every phase to fresh subagents with quality gates at every transition. You approve the plan once; it handles the rest. |
| [`/ship:plan`](#plan) | **Adversarial Planner** | Reads your codebase, writes a plan, then hands it to an independent Codex challenger. Two rounds of adversarial review. A blind execution drill. You see the plan only after it survives falsification. |
| [`/ship:dev`](#dev) | **Implementation Engine** | Executes stories from a plan. Codex writes code, Claude reviews — different models catching each other's blind spots. Stories run sequentially; review must pass before the next one starts. |
| [`/ship:review`](#review) | **Staff Engineer** | Find every bug in the diff, then diagnose the structural deficiency that breeds them. Bugs are symptoms — the structural crack is the disease. |
| [`/ship:qa`](#qa) | **Independent QA** | Starts your app, tests every acceptance criterion against the running product. Independence contract: cannot read the review or plan. Only direct observation counts. |
| [`/ship:handoff`](#handoff) | **Release Engineer** | Creates a PR with a proof bundle, then enters the fix loop: CI failures, review comments, merge conflicts. Doesn't stop until the PR is merge-ready or retries are exhausted. |
| [`/ship:refactor`](#refactor) | **Structural Diagnostician** | Traces from concrete pain to structural cracks. Diagnoses and fixes directly — surgical (within-file) or structural (cross-file) execution. |
| [`/ship:setup`](#setup) | **Repo Bootstrapper** | Detects stack, installs tools, configures CI/CD and pre-commit hooks, discovers semantic constraints from code and git history, generates AGENTS.md + CONVENTIONS.md + hookify safety rules. Audits existing harness for staleness. |

---

## `auto`

This is the **full pipeline**.

You describe what you want to build. Ship handles the rest — plan, implement, review, verify, QA, simplify, handoff — with quality gates at every transition.

### Why an orchestrator?

AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

The orchestrator itself is **read-only**. It never reads code, never writes code, never touches artifacts. All it does is delegate to fresh subagents and check quality gates. This preserves the coordination window for decisions that matter — instead of filling it with implementation details that bias every downstream phase.

### The GAN architecture

Implementation and review use **different models**. Codex generates code. Claude reviews it. Their blind spots don't overlap. This is the same principle that makes GANs work — the generator and discriminator improve each other because they fail in different ways.

The QA evaluator is contractually forbidden from reading the review or the plan. It can only look at the spec and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

### Nine phases

```
Plan → Approve → Dev → Review → Verify → QA → Simplify → Handoff
```

1. **Bootstrap** — init task directory, detect tooling
2. **Design** — invoke `/ship:plan` for adversarial planning
3. **Approve** — present the plan to you. This is the only human gate.
4. **Dev** — invoke `/ship:dev` to execute implementation stories
5. **Review** — invoke `/ship:review` for staff-engineer code review
6. **Verify** — run tests + lint. Up to 3 retry rounds.
7. **QA** — invoke `/ship:qa` against the running application
8. **Simplify** — behavior-preserving cleanup (dead code, redundant abstractions)
9. **Handoff** — invoke `/ship:handoff` to create PR and shepherd it to merge-ready

Every transition has a quality gate. If the gate fails, the phase retries with strict caps (verify: 3, review: 3, QA: 2) before escalating to you.

### State lives on disk

The current phase is derived from which artifacts exist: `plan/spec.md` present → design done. `review.md` filled → review done. `qa/qa.md` has a PASS verdict → QA done. The stop-gate hook checks these artifacts before allowing the session to exit — if any phase was skipped or incomplete, you're sent back.

### Example

```
You:   Add rate limiting to the /api/upload endpoint

Claude: [Ship] Bootstrapping task: rate-limit-upload
        [Ship] Phase 2: Design — investigating codebase...

        [Plan] Read src/routes/api/upload.ts, traced to middleware chain...
        [Plan] Found existing rate limiter in src/middleware/rateLimit.ts
               but /api/upload bypasses it (line 42, direct route mount).
        [Plan] Codex challenger confirmed: both plans agree on middleware approach.
        [Plan] Execution drill passed — 3 stories, all implementable.

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

        Approve this plan? (Y to proceed, N to revise)

You:    Y

Claude: [Ship] Phase 4: Implementing 3 stories...
        [Dev] Story 1: PASS — middleware wired, tests green
        [Dev] Story 2: PASS — quota logic added with Redis counter
        [Dev] Story 3: PASS — 429 + Retry-After verified

        [Ship] Phase 5: Code Review...
        [Review] 1 finding: Redis key missing TTL — auto-fixed.

        [Ship] Phase 6: Verify — tests pass, lint clean.

        [Ship] Phase 7: QA — testing against running app...
        [QA] 3/3 MUST criteria passed (L1 evidence: curl responses)
        [QA] 1/1 SHOULD criteria passed
        [QA] Verdict: PASS (score: 95/100)

        [Ship] Phase 8: Simplify — no dead code found.

        [Ship] Phase 9: Handoff — creating PR...
        PR #48 created. CI passing. Ready for review.
```

One command. Task description to merge-ready PR. You approved the plan once. Everything else was autonomous.

---

## `plan`

This is where **adversarial rigor** meets planning.

Most AI planning is a monologue. The model reads your request, skims the codebase, and writes a plan that sounds reasonable. The problem: "sounds reasonable" is not "survives contact with reality." Plans fail when they reference files that don't exist, assume APIs that have different signatures, or miss existing defenses that already handle the case.

`plan` fixes this with a simple rule: **no investigation, no plan.**

### How it works

The planner doesn't skim. It traces full call paths from entry points, reads the actual files, records file:line evidence for every claim. Every statement in the plan must be grounded in code you can point to.

Then the plan faces a challenger.

### The adversarial loop

After the planner writes Plan A, Codex independently produces Plan B — without ever seeing Plan A. This is not a review. It is an independent investigation of the same problem by a different model.

Then the diff:

- **Both plans agree** → CONFIRMED. High confidence.
- **Plans diverge** → resolution by code evidence, not by reasoning. Read the file. Check the type signature. Grep for the constant. One plan is right and one is wrong, and the code tells you which.

### The execution drill

After convergence, one final gate: Codex walks the plan step by step as if it were the implementer. Every step where it would have to guess — unclear file path, ambiguous function name, missing context — gets flagged.

The planner addresses each flag with evidence or revises the step. Plans that survive this drill are implementable. Plans that don't get revised until they are.

### Example

```
You:   Plan out adding WebSocket support for real-time notifications

Claude: [Plan] Phase 2: Investigating codebase...
        Read src/server.ts — Express app, no existing WS setup.
        Read src/routes/notifications.ts — polling endpoint, 5s interval.
        Read src/services/notificationService.ts — pushes to Redis pub/sub.
        Read package.json — no ws/socket.io dependency.

        [Plan] Phase 3: Writing Plan A...
        Spec: Replace polling with WebSocket push.
        3 stories with file:line references for every touchpoint.

        [Plan] Phase 4: Codex producing Plan B independently...
        [Plan] Phase 5: Comparing plans...

        CONFIRMED: Both plans use ws library (not socket.io).
        CONFIRMED: Both plans hook into existing Redis pub/sub.
        DIVERGENCE: Plan A modifies server.ts directly.
                    Plan B creates separate ws-server.ts.
                    → Read server.ts:14 — already has upgrade handler
                      for health checks. Plan B is right: separate file
                      avoids conflict.
                    → Plan A revised.

        [Plan] Phase 6: Execution drill...
        Codex flagged: "Step 2 says 'update the notification type' but
        doesn't specify which file defines NotificationType."
        → Added: src/types/notification.ts:8

        Plan complete. 3 stories, all implementable.
```

---

## `dev`

This is the **implementation engine**.

It takes a plan with concrete stories and executes them one at a time. But the key insight is who does what: **Codex generates, Claude discriminates.**

### Why two models?

Self-review doesn't work. When the same model writes code and reviews it, the review inherits all the blind spots of the implementation. It's like proofreading your own essay — you read what you meant to write, not what you actually wrote.

Ship separates the roles. Codex implements each story via MCP. Then a fresh Claude agent — with no knowledge of the implementation session — reviews for spec compliance and code correctness. Different models fail in different ways. That's the point.

### The story loop

For each story in the plan:

1. **Record start SHA** — so we can diff exactly what changed
2. **Codex implements** — fresh MCP session with the story spec, plan context, and code conventions
3. **Claude reviews** — fresh agent, different model, sees only the diff and the spec
4. **If FAIL** — targeted fix (max 2 rounds), not a full rewrite
5. **Record cross-story context** — later stories know what earlier stories built

After all stories, a cross-story regression test catches interactions between stories that individual reviews missed.

### Example

```
You:   /ship:dev

Claude: [Dev] Reading plan: 3 stories for rate-limit-upload

        [Dev] Story 1/3: Wire /api/upload through rate limiter
        [Codex] Implementing... done (4 files changed)
        [Review] Checking spec compliance...
        [Review] PASS — middleware correctly applied, test added

        [Dev] Story 2/3: Add per-user upload quota
        [Codex] Implementing... done (3 files changed)
        [Review] Checking spec compliance...
        [Review] FAIL — Redis key uses IP instead of user ID
        [Dev] Targeted fix round 1...
        [Review] PASS

        [Dev] Story 3/3: Return 429 with Retry-After header
        [Codex] Implementing... done (2 files changed)
        [Review] PASS

        [Dev] Cross-story regression: all tests green.
        [Dev] 3/3 stories complete.
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

Claude: [QA] Reading spec and diff...
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

### The proof bundle

Handoff doesn't just create a PR. It carries evidence. Every PR body includes a proof table:

| Artifact | Status | SHA |
|----------|--------|-----|
| Tests | PASS (47/47) | a1b2c3d |
| Lint | PASS | a1b2c3d |
| Coverage | 89% (+3%) | a1b2c3d |
| QA | PASS (97/100) | a1b2c3d |

The SHA stamps prove the evidence matches the code being merged, not some earlier version that has since changed.

### The fix loop

After creating the PR, handoff enters a loop:

1. Wait for CI
2. If CI fails → read logs, dispatch fix, re-push
3. If review comments → mechanical fixes auto-addressed, judgment calls escalated
4. If merge conflicts → auto-resolve, re-verify

Max 2 rounds. If it can't get the PR merge-ready in 2 rounds, it escalates to you with a clear explanation of what's blocking.

### Harness freshness check

Before declaring the PR ready, handoff verifies that harness docs (AGENTS.md, CONVENTIONS.md, README.md) still match the code. Stale documentation is treated as a PR-blocking finding — not background noise.

### What it won't do

- Never force push
- Never skip tests
- Never auto-merge (creates the PR, doesn't merge it)
- Never address security or architecture review comments without asking you

### Example

```
You:   /ship:handoff

Claude: [Handoff] Checking proof freshness...
        Tests: PASS at a1b2c3d (current HEAD) ✓
        Lint: PASS at a1b2c3d ✓
        QA: PASS at a1b2c3d ✓

        [Handoff] Merging main into feature branch... clean.
        [Handoff] Creating PR #48...

        [Handoff] Waiting for CI...
        CI: 3/3 checks passed ✓

        [Handoff] PR #48 is merge-ready.
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

Claude: [Refactor] Tracing from pain...
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

- **Semantic rules** (CONVENTIONS.md) — things only AI can judge: "don't remove auth to fix errors", "price is in cents not dollars", "legacy module is being migrated". Injected into every session via SessionStart hook.
- **Safety rules** (hookify) — deterministic regex checks: block editing .env files, block DROP TABLE. Real-time PreToolUse blocking.

If harness files already exist (AGENTS.md, CLAUDE.md, CONVENTIONS.md), setup audits them for staleness before generating.

### Three-layer defense

| Layer | Tool | How | Cost |
|-------|------|-----|------|
| Real-time block | Hookify rules | regex on PreToolUse | Free |
| Semantic context | CONVENTIONS.md | SessionStart injection | Free |
| Commit-time | Pre-commit hook | lint + format | Free |

### Example

```
You:   /ship:setup

Claude: [Setup] Detecting stack...
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

        SEMANTIC RULES (CONVENTIONS.md):
          ✓ [S1] Don't remove auth checks to fix errors
              Why: AI agents delete validation to make errors go away

        [Setup] Complete.

        AGENTS.md: generated
        CONVENTIONS.md: 1 semantic rule
        Hookify: 1 safety rule
        Pre-commit: wired via core.hooksPath
```
