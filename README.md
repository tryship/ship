# Ship: AI-Powered Software Development Harness

Ship is a plugin for Claude Code that orchestrates end-to-end software development — from planning through implementation, review, QA, and PR creation — with quality gates at every transition.

## How It Works

Ship is a harness, not a copilot. It doesn't help AI write code — it constrains AI to produce reliable results through mechanically enforced quality gates.

**The problem Ship solves:** AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

**The orchestrator is read-only.** A shell hook (`guard-orchestrator.sh`) mechanically blocks the orchestrator from writing files, reading diffs, or running tests. It can only READ, DECIDE, and DELEGATE. This isn't a suggestion — it's enforced at the tool level. The orchestrator's sole job is to dispatch fresh subagents with precisely crafted context and decide what to do with their output.

**Every phase is an isolated subagent.** The reviewer has never seen the implementation context. The QA evaluator is contractually forbidden from reading the review or verification artifacts — it can only look at the spec and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

**State lives on disk, not in memory.** There are no state files. The current phase is derived from which artifacts exist: `plan/spec.md` present → design done. `review.md` filled → review done. The stop-gate hook checks these artifacts before allowing the session to exit — if any phase was skipped or incomplete, you're sent back.

**Plans are adversarially tested.** The planner reads your codebase (tracing call chains, mapping integration surfaces, grepping for existing defenses), writes a spec and plan, then hands it to an independent Codex challenger. The challenger produces falsification cards — code-grounded objections with file paths and snippets. The planner must respond with code evidence, not hand-waving. Two rounds of this before you see anything.

**Evidence is hierarchical.** L1 (saw it yourself — screenshot, curl response body, console log) is the only acceptable evidence for MUST criteria. L2 (HTTP 200 alone, "tests passed") is insufficient. L3 ("should work based on the code") is an automatic FAIL. The QA evaluator enforces this mechanically.

**The finish line is a merge-ready PR, not a PR.** After creating the PR with a proof bundle, Ship enters a fix loop: wait for CI, read failure logs, dispatch fixes, address review comments, resolve merge conflicts — up to 2 rounds before escalating. PR creation is the midpoint, not the end.

You describe what you want to build. Ship handles the constraints that make AI output trustworthy.

## Core Philosophy

- **Orchestrator pattern** — a read-only orchestrator delegates every phase to fresh subagents with isolated context, preserving the coordination window for decisions that matter
- **Adversarial planning** — plans are stress-tested through independent Codex challenger rounds before any code is written
- **Evidence over claims** — every phase produces artifacts on disk; quality gates verify artifacts exist and pass before advancing
- **Test-driven development** — implementation follows a RED-GREEN-REFACTOR cycle with per-story code review

## The Basic Workflow

**setup** — Run once per repo. Detects languages and package managers, installs missing linters/formatters/type checkers/test runners, sets up CI/CD workflows, and generates AGENTS.md. Idempotent — safe to run again.

**plan** — Reads the codebase yourself (no delegation), traces call chains and integration surfaces, writes spec + plan with file:line references. Hands it to an independent Codex challenger for 2 rounds of adversarial review. You see the plan only after it survives falsification.

**auto** — The full pipeline. Bootstraps a task directory, invokes plan, presents the design for your approval, then runs implement → review → verify → QA → simplify → handoff autonomously. The orchestrator is read-only — a guard hook blocks it from touching files. Every phase is a fresh subagent dispatch.

**implement** — Executes stories one by one. Each story goes to codex for TDD implementation, then to a fresh reviewer agent for code quality + spec compliance + convention compliance. On failure: targeted fix, not re-implementation. Max 2 fix rounds per story before escalating.

**review** — Independent code review against the spec. Dispatched as a fresh agent that has never seen the implementation context. Findings are categorized by severity; critical issues block progress.

**qa** — Starts the application, builds a rubric from the spec, and tests every acceptance criterion against the running product. Independence contract: cannot read review.md, verify.md, or plan.md. Only L1 evidence (direct observation) counts for MUST criteria. Reports verdict with fix guidance.

**handoff** — Creates a PR with proof bundle (test results, lint, coverage, QA verdict, spec compliance). Then enters the post-PR loop: poll CI, fix failures, address review comments, resolve merge conflicts. Doesn't stop until the PR is merge-ready or retries are exhausted.

**debug** — For when the cause is unknown. Reproduces the failure, isolates the root cause through systematic narrowing, writes the smallest fix with a mandatory regression test. No simplify pass — debug fixes should be minimal.

**refactor** — Captures behavioral baseline first, then refactors in small incremental steps. Every step must pass existing tests before moving on. Review focuses specifically on behavior preservation, not just code quality.

Skills trigger automatically based on what you're doing. The harness enforces the workflow — you don't need to remember the process.

## Skills

| Skill | Description |
|-------|-------------|
| `/ship:auto` | Full 9-phase coding pipeline: design → implement → review → verify → QA → simplify → PR |
| `/ship:plan` | Adversarial pre-coding planning with Codex challenger (2-round convergence) |
| `/ship:implement` | Per-story implementation with TDD, code review, and targeted fix loops |
| `/ship:debug` | Root cause investigation and targeted repair for unknown failures |
| `/ship:refactor` | Behavior-preserving code cleanup with baseline comparison |
| `/ship:qa` | Independent QA evaluation: functional, exploratory, and health testing with L1 evidence |
| `/ship:handoff` | PR creation with proof bundle, CI fix loop, and review comment resolution |
| `/ship:setup` | Bootstrap a repo from zero to AI-ready (linters, formatters, CI/CD, AGENTS.md) |
| `/ship:review` | Review code for bugs, security issues, and best practices |
| `/ship:test` | Write and run tests for code changes |
| `/ship:clean` | Clean up dead code, unused imports, and unnecessary complexity |

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace first:

```
/plugin marketplace add tryship/ship
```

Then install the plugin:

```
/plugin install ship@ship
```

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/tryship/ship/refs/heads/main/.codex/INSTALL.md
```

### Local Development

Clone the repo and point Claude Code at it:

```bash
git clone https://github.com/tryship/ship.git
claude --plugin-dir ./ship
```

### Verify Installation

Open a fresh session and give it a task that would trigger a skill — for example, "plan out a user authentication system" or "debug why the API returns 500 on empty input". Ship should kick in automatically and run the corresponding workflow.

### Updating

```
/plugin update ship
```

## Links

- Website: https://ship.tech
- Repository: https://github.com/tryship/ship
