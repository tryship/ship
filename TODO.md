# Ship — TODO

## P0: Enterprise Core

- [ ] **CI gate GitHub Action** — PR-level policy verification. Validates: policy.base.json not tampered (checksum), repo policy doesn't relax base rules, AI-generated code passes all policy checks. Prevents local bypass. (`skills/setup/templates/ci-ship-policy.yml`)
- [ ] **Rules system** — Machine-executable coding standards per org. Import org conventions, enforce during review phase, generate compliance report. Not prompt hints — enforceable rules checked by hooks. (`bin/policy-rules.sh`, `.ship/rules/`)
- [ ] **Org-level setup** — `ship init --org` generates org config, `ship init --repo` inherits. Batch onboarding for 30+ repos. Onboarding status tracking.

## P1: Quality & Trust

- [ ] **Session learning** — Per-project `.ship/learnings.md`. After each debug/review, append what was learned. Inject at SessionStart for future sessions. Minimal viable version, not full instinct system.
- [ ] **Dependency audit** — Beyond secrets scanning. Check AI-introduced dependencies against known vulnerability DBs. Hook into `npm audit` / `pip audit` / `go vuln`. Add to `quality.pre_commit` or as a separate PostToolUse check.
- [ ] **Complete stub skills** — `test` (write and run tests), `clean` (dead code removal), `review` (code review). Currently stubs in `skills/`.

## P2: Ecosystem

- [ ] **MCP configurations** — Ship-specific MCP configs for GitHub, Supabase, Playwright, etc. Provide extended tool access during QA and implementation phases.
- [ ] **Benchmark suite** — Quantify Ship vs vanilla Claude Code. Metrics: review pass rate, test coverage delta, security violation rate, time-to-PR. Use on real tasks to generate marketing data.
- [ ] **Cross-platform adapters** — `.cursor/`, `.codex/`, `.opencode/` adapter layers. Policy enforcement for non-Claude Code environments. V2 — validate demand first.

## P3: Observability

- [ ] **Audit dashboard** — Parse `.ship/audit/*.jsonl` into a human-readable report. Weekly summary: AI operations count, policy violations, file modification frequency, developer breakdown. CLI command: `ship report --last 7d`.
- [ ] **Compliance export** — Export audit logs in formats compatible with enterprise compliance tools (CSV, SIEM-compatible JSON). For SOC2/ISO27001 customers.

## Done (this sprint)

- [x] Policy schema design (JSON format, 5 sections)
- [x] Always-on enforcement hooks (boundaries, operations, secrets, audit)
- [x] Org-level inheritance (policy.base.json merge)
- [x] stop-gate policy integration (workflow.phases)
- [x] Default policy template (language-aware)
- [x] Setup SKILL.md Phase 2.5 policy generation
- [x] AGENTS.md generation
- [x] Preamble fix (non-pipeline skills skip state file)
- [x] QA: 14/14 acceptance criteria pass
- [x] Review: 5 findings fixed (jq paths, POSIX grep, glob, eval, symlinks)
