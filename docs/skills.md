# Skill Deep Dives

Detailed guides for every Ship skill — philosophy, workflow, and examples.

| Skill | Role | What it does |
|-------|------|--------------|
| [`/ship:ship-auto`](#ship-auto) | **Pipeline Orchestrator** | The full pipeline. One command from task description to merge-ready PR. Delegates every phase to fresh subagents with quality gates at every transition. You approve the plan once; it handles the rest. |
| [`/ship:ship-plan`](#ship-plan) | **Adversarial Planner** | Reads your codebase, writes a plan, then hands it to an independent Codex challenger. Two rounds of adversarial review. A blind execution drill. You see the plan only after it survives falsification. |
| [`/ship:ship-dev`](#ship-dev) | **Implementation Engine** | Executes stories from a plan. Codex writes code, Claude reviews — different models catching each other's blind spots. Stories run sequentially; review must pass before the next one starts. |
| [`/ship:ship-review`](#ship-review) | **Staff Engineer** | Review code for bugs, security issues, and best practices. Structural audit, not style nitpicks. |
| [`/ship:ship-qa`](#ship-qa) | **Independent QA** | Starts your app, tests every acceptance criterion against the running product. Independence contract: cannot read the review or plan. Only direct observation counts. |
| [`/ship:ship-handoff`](#ship-handoff) | **Release Engineer** | Creates a PR with a proof bundle, then enters the fix loop: CI failures, review comments, merge conflicts. Doesn't stop until the PR is merge-ready or retries are exhausted. |
| [`/ship:ship-refactor`](#ship-refactor) | **Structural Diagnostician** | Traces from concrete pain to structural cracks. Writes a refactor spec, then hands off to auto for execution. |
| [`/ship:ship-setup`](#ship-setup) | **Repo Bootstrapper** | One command. Detects your stack, installs missing tools, configures CI/CD, discovers coding conventions, generates AGENTS.md and CONVENTIONS.md, registers enforcement. |

---

## `ship-auto`

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
2. **Design** — invoke `ship-plan` for adversarial planning
3. **Approve** — present the plan to you. This is the only human gate.
4. **Dev** — invoke `ship-dev` to execute implementation stories
5. **Review** — independent code review via Codex MCP
6. **Verify** — run tests + lint. Up to 3 retry rounds.
7. **QA** — invoke `ship-qa` against the running application
8. **Simplify** — behavior-preserving cleanup (dead code, redundant abstractions)
9. **Handoff** — invoke `ship-handoff` to create PR and shepherd it to merge-ready

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

## `ship-plan`

This is where **adversarial rigor** meets planning.

Most AI planning is a monologue. The model reads your request, skims the codebase, and writes a plan that sounds reasonable. The problem: "sounds reasonable" is not "survives contact with reality." Plans fail when they reference files that don't exist, assume APIs that have different signatures, or miss existing defenses that already handle the case.

`ship-plan` fixes this with a simple rule: **no investigation, no plan.**

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

## `ship-dev`

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
You:   /ship:ship-dev

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

## `ship-review`

This is the **paranoid staff engineer**.

Code review isn't about style. It's about asking: **what can still break?**

Ship's review looks for the class of bugs that survive CI but explode in production:

- N+1 queries hiding behind pagination
- Race conditions in concurrent write paths
- Trust boundary violations (user input flowing into privileged operations)
- Missing error handling on partial failures
- Tests that pass while testing the wrong thing
- Forgotten enum handlers when new values are added

Obvious mechanical fixes (dead code, stale comments, missing null checks) are applied automatically. Genuinely ambiguous issues (architecture decisions, security tradeoffs) are surfaced for your call.

---

## `ship-qa`

This is **independent QA**.

The most important word is "independent." The QA evaluator is contractually forbidden from reading the review, the verification results, or the plan. It can only look at two things: the spec (what was supposed to be built) and the running application (what was actually built). This independence contract exists because every other phase has optimistic bias — the implementer thinks their code works, the reviewer saw the implementation context, the verifier ran the tests the implementer wrote. QA is the outsider.

### Evidence hierarchy

Not all evidence is equal:

- **L1 — Direct observation.** You saw it yourself. Screenshot, curl response body, console log. This is the only acceptable evidence for MUST criteria.
- **L2 — Indirect signal.** HTTP 200, "tests passed." Acceptable for SHOULD criteria only.
- **L3 — Assumption.** "Should work based on the code." Automatic FAIL.

HTTP 200 is not proof. The QA evaluator must inspect the response body, check the DOM, verify the actual behavior — not just confirm the server didn't crash.

### Three layers

1. **Functional verification** — test every acceptance criterion from the spec against the running app
2. **Exploratory testing** — go beyond the spec. Edge cases, error paths, unexpected inputs. Findings here don't affect the verdict but are reported.
3. **Health check** — console errors, HTTP 500s, page load time, broken assets

### Example

```
You:   /ship:ship-qa

Claude: [QA] Starting application... server ready on :3000
        [QA] Building rubric from spec: 3 MUST, 1 SHOULD criteria

        [QA] Functional Verification:
        MUST-1: 429 after 100 uploads/hour — PASS
                Evidence (L1): curl response, status=429, body={"error":"rate limited"}
        MUST-2: Retry-After header present — PASS
                Evidence (L1): Retry-After: 3600
        MUST-3: Non-upload endpoints unaffected — PASS
                Evidence (L1): GET /api/status returns 200 during rate limit
        SHOULD-1: Existing rate limiter tests pass — PASS
                Evidence (L2): npm test exit code 0, 47/47 passing

        [QA] Exploratory Testing:
        - Tested concurrent uploads from same user: rate limit triggers correctly
        - Tested unauthenticated requests: returns 401 before rate limit check (good)
        - Edge: exactly 100th request returns 200, 101st returns 429 ✓

        [QA] Health Check:
        Console errors: 0
        HTTP 500s: 0
        Load time: 340ms (p95)

        Verdict: PASS (score: 97/100)
        Report written to .ship/tasks/rate-limit-upload/qa/qa.md
```

---

## `ship-handoff`

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

### What it won't do

- Never force push
- Never skip tests
- Never auto-merge (creates the PR, doesn't merge it)
- Never address security or architecture review comments without asking you

### Example

```
You:   /ship:ship-handoff

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

## `ship-refactor`

This is the **structural diagnostician**.

Refactoring is not "clean up the code." It's answering: **why does adding a feature feel harder than it should?**

### Trace from pain, not from structure

Bad refactoring starts with "this module is too big" or "we should use the repository pattern." Good refactoring starts with a specific pain: "every time we add a new notification type, we have to change 4 files." That pain traces to a structural crack — a boundary that doesn't match how the code is actually used.

`ship-refactor` traces from the concrete pain to the crack:

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

A refactor spec — not code. The spec describes the pain, the current structure, the crack, the target structure, and acceptance criteria. Then it hands off to `ship-auto`, which produces the plan, implements it, reviews it, tests it, and ships it.

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

## `ship-setup`

This is the **one-command bootstrap**.

New repo? Inherited codebase? Missing linter? No CI? `ship-setup` handles all of it — and then goes further by discovering the coding conventions your team follows but never wrote down.

### Part 1: Infrastructure

Setup scans your repo and detects everything: languages (14 supported), package managers, linters, formatters, type checkers, test runners, CI/CD, pre-commit hooks. It tells you what's ready, what's missing, and what's broken. Then you pick which modules to configure:

1. **Install missing tools** — linter, formatter, type checker for your stack
2. **Pre-commit hooks** — lint + format on every commit
3. **CI/CD** — GitHub Actions workflows
4. **Dependabot** — automated dependency updates
5. **AI Code Review** — automated review on PRs

It never assumes. It never invents a default stack. If your repo already uses ESLint, it wires ESLint into pre-commit — it doesn't install Biome because it thinks Biome is better.

### Part 2: Harness

After infrastructure, setup reads your code — not all of it, but targeted investigation from entry points 2-3 levels deep. It finds patterns repeated across 3+ files that your linter can't enforce: error handling conventions, validation patterns, module boundaries, naming rules.

Every convention must have file:line evidence. No templates, no presets, no dogma. If the pattern isn't in the code, it doesn't become a rule.

Then it generates:
- **AGENTS.md** — the AI handbook for your repo. Commands, architecture, conventions, gotchas.
- **CONVENTIONS.md** — semantic rules with correct/incorrect examples, enforced by a hook on every Write/Edit.

### Example

```
You:   /ship:ship-setup

Claude: [Setup] Detecting stack...
        TypeScript (pnpm), Python (uv)
        Linter: oxlint (ready), ruff (ready)
        Formatter: prettier (ready), ruff (ready)
        Type checker: tsc (ready), pyright (missing)
        Test runner: vitest (ready), pytest (ready)
        CI/CD: none
        Pre-commit: none

        Select modules:
        1. [x] Install missing tools (pyright)
        2. [x] Pre-commit hooks
        3. [ ] CI/CD (GitHub Actions)
        4. [ ] Dependabot
        5. [ ] AI Code Review

You:    A (all recommended)

Claude: [Setup] Installing pyright... done
        [Setup] Configuring lint-staged + husky... done
        [Setup] Configuring GitHub Actions CI... done
        [Setup] Adding dependabot.yml... done
        [Setup] Configuring AI code review... done

        [Setup] Part 2: Investigating conventions...
        Read src/server.ts → src/middleware/ → src/routes/
        Read src/services/ → src/repositories/

        Found 4 conventions linters can't cover:

        ✓ [1] All service methods return Result<T, AppError>
              Evidence: src/services/user.ts:12, billing.ts:8, auth.ts:15 (7/7)
        ✓ [2] Repository methods throw, services catch and wrap
              Evidence: src/repositories/user.ts:23, src/services/user.ts:14 (5/5)
        ✓ [3] Route handlers never call repositories directly
              Evidence: 0 imports from repositories/ in routes/ (12 files checked)
        ✓ [4] Error responses use AppError.toResponse()
              Evidence: src/middleware/errorHandler.ts:8, routes/api.ts:34 (6/6)

You:    Generate as shown

Claude: [Setup] Complete.

        AGENTS.md: generated (142 lines)
        CONVENTIONS.md: 4 conventions
        Hook: registered in .claude/settings.json

        Every Write/Edit will now be checked against these conventions.
```
