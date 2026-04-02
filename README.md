# Ship: AI-Powered Software Development Harness

Ship is a plugin for Claude Code that orchestrates end-to-end software development — from planning through implementation, review, QA, and PR creation — with quality gates at every transition.

## How It Works

Ship is a harness, not a copilot. It doesn't help AI write code — it constrains AI to produce reliable results through mechanically enforced quality gates.

**The problem Ship solves:** AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

**Quality gates at every transition.** The `stop-gate.sh` hook prevents the orchestrator from exiting until all pipeline phases are complete. Each phase produces artifacts that the next phase consumes — no shortcuts, no skipped steps.

**Every phase is an isolated subagent.** The reviewer has never seen the implementation context. The QA evaluator is contractually forbidden from reading the review or verification artifacts — it can only look at the spec and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

**State lives on disk, not in memory.** The current phase is derived from which artifacts exist: `plan/spec.md` present → design done. `review.md` filled → review done. The stop-gate hook checks these artifacts before allowing the session to exit — if any phase was skipped or incomplete, you're sent back.

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

**setup** — Bootstrap repo infrastructure (detect languages, install tools, configure CI/CD, pre-commit hooks) and discover semantic constraints from code and git history. Generates AGENTS.md, CONVENTIONS.md (injected at session start), and hookify safety rules. Audits existing harness for staleness.

**plan** — Reads the codebase yourself (no delegation), traces call chains and integration surfaces, writes spec + plan with file:line references. Hands it to an independent Codex challenger for 2 rounds of adversarial review. You see the plan only after it survives falsification.

**auto** — The full pipeline. Bootstraps a task directory, invokes plan, presents the design for your approval, then runs dev → review → verify → QA → simplify → handoff autonomously. The orchestrator is read-only — a guard hook blocks it from touching files. Every phase is a fresh subagent dispatch.

**dev** — Executes implementation stories from a plan. Codex implements each story, Claude reviews spec compliance and code correctness. Stories run sequentially.

**review** — Find every bug in the diff — spec violations, runtime errors, race conditions, missing error handling — then diagnose the structural deficiency that breeds them. No style or formatting nits.

**qa** — Starts the application and tests the code changes against the spec by interacting with the running product. Discovers the stack, matches testing to what changed (browser, API, CLI), and reports findings with evidence. Browser testing uses [agent-browser](https://github.com/vercel-labs/agent-browser). Independence contract: cannot read review.md, verify.md, or plan.md.

**handoff** — Creates a PR with proof bundle (test results, lint, coverage, QA verdict, spec compliance). Then enters the post-PR loop: poll CI, fix failures, address review comments, resolve merge conflicts. Doesn't stop until the PR is merge-ready or retries are exhausted.

**refactor** — Diagnose structural cracks from concrete pain, then fix directly. Surgical (within-file) or structural (cross-file) execution — code changes, not documents.

Skills trigger automatically based on what you're doing. The harness enforces the workflow — you don't need to remember the process.

## Skills

| Skill | Description |
|-------|-------------|
| `/ship:auto` | Full pipeline orchestrator: plan → dev → review → verify → QA → simplify → handoff |
| `/ship:plan` | Adversarial pre-coding planning with Codex challenger (2-round convergence) |
| `/ship:dev` | Execute implementation stories from a plan — Codex implements, Claude reviews |
| `/ship:review` | Find every bug in the diff, then diagnose the structural deficiency that breeds them |
| `/ship:qa` | Independent QA: tests code changes against the spec via the running application |
| `/ship:handoff` | PR creation with proof bundle, CI fix loop, and review comment resolution |
| `/ship:refactor` | Diagnose structural cracks and fix directly — surgical or structural execution |
| `/ship:setup` | Bootstrap infra + discover semantic constraints, generate AGENTS.md + CONVENTIONS.md + hookify safety rules |

## Installation

### Claude Code (via ShipAI)

Register the plugin source first:

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

## References

Ship is built on ideas from:

- [agent-browser](https://github.com/vercel-labs/agent-browser) — Vercel's headless browser CLI for AI agents
- [Superpowers](https://github.com/obra/superpowers) — Jesse Vincent's skill library for Claude Code
- [gstack](https://github.com/garrytan/gstack) — Garry Tan's full-stack AI development harness

## Links

- Website: https://www.ship.tech
- Repository: https://github.com/tryship/ship
