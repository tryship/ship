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

---

## Research Context (2026-03-29)

### Competitive Landscape

**oh-my-claudecode (OMC)** — 14K stars. Multi-agent orchestration system. 29 agents across 3 model tiers (Haiku/Sonnet/Opus), 32 skills, 31 hooks. Key features: magic keyword routing ("autopilot", "ralph"), Sisyphus-style persistence loops (verify/fix until done), multi-provider (Claude+Gemini+Codex), notepad wisdom system, session replay logs. Differentiator: throughput via intelligent routing. Weakness: no information isolation, no adversarial planning, opt-in only.

**everything-claude-code (ECC)** — 113K stars. Full-stack config ecosystem. 28 agents, 125+ skills, 60+ commands, 12 language ecosystems. Key features: AgentShield security scanner (1,282 tests, 102 rules), instinct system (confidence-scored learning with 30-day TTL), cross-platform (6 platforms: Claude Code, Cursor, Codex, OpenCode, Kiro, Antigravity). Won Cerebral Valley x Anthropic hackathon. Differentiator: breadth and battle-tested defaults. Weakness: opt-in, no enforcement guarantees, no adversarial design.

### Market Validation

- **45% of AI-generated code has security flaws** (Veracode, 100+ LLMs tested). Java worst at 72%. Security pass rates flat at 45-55% despite syntax improving to 95%.
- **AI code has 2.74x more security vulnerabilities** than human-written code. 74 CVEs directly from AI code tracked by Georgia Tech (est. 400-700 actual).
- **88% of organizations reported AI agent security incidents** (2025), but only 14.4% deploy with full security approval.
- **Real incidents:** Moltbook (vibe-coded) leaked 1.5M auth tokens + 35K emails. Base44 SaaS had auth bypass from AI-generated URI bug.
- **Capital flowing in:** Axiom $200M (verifiable AI code safety), Kai $125M (agentic AI cybersecurity), JetStream $34M seed (AI control infrastructure).
- **GitHub shipped Enterprise AI Controls + Agent Control Plane GA** (Feb 2026) — enterprise policy, agent activity audit, API-level management.
- **CodeGate (Stacklok) discontinued** — pure security proxy model wasn't sticky enough. Lesson: guardrails alone don't retain; need workflow value too.
- **Stack Overflow 2025:** "Developers remain willing but reluctant to use AI" — 73% daily use, but only 29-46% trust output, 96% don't "fully" trust.

### Ship's Strategic Position

**Value proposition:** "The only harness that makes AI coding trustworthy through mechanical enforcement + adversarial verification + audit trail."

**Differentiation formula:** Always-on policy (what AI can't do) + Adversarial workflow (how AI work gets verified) + Audit trail (proof of compliance).

**Why Ship wins vs alternatives:**
- vs OMC/ECC: They're opt-in productivity tools. Ship is always-on enforcement. Developer can't bypass.
- vs GitHub Enterprise AI Controls: GitHub does policy + audit. Ship adds adversarial workflow (the verification layer GitHub doesn't have).
- vs CodeGate (dead): CodeGate was policy-only, no workflow value. Ship has both.
- vs Snyk/Veracode: They scan after the fact. Ship prevents before the fact (PreToolUse deny).

**Target buyer:** CTO / Engineering VP asking "How do I let my team use AI coding safely?"

**Key metrics for buyers:** compliance rate, review pass rate, zero production incidents from AI code.

### Architecture Decisions Made

| Decision | Choice | Why |
|----------|--------|-----|
| Policy format | JSON (not YAML) | jq-only dependency, no PyYAML/yq needed |
| Policy location | `.ship/ship.policy.json` | Git-tracked, PR-reviewable |
| Action model | block / warn / allow | block=absolute, warn=human confirm+audit, allow=unrestricted |
| Action granularity | Section default + per-rule override | CTO sets defaults, exceptions where needed |
| Policy self-protection | warn (not block) | AI can propose changes, human approves |
| Org inheritance | `policy.base.json` + merge (only add-strict) | Base block can't be relaxed to warn |
| Secret scanning | PreToolUse (not PostToolUse) | Deny before write, secret never reaches disk |
| Subagent policy | No bypass | Implementation subagents must follow policy too |
| Enforcement point | Local hooks + CI gate (future) | Local for real-time, CI for tamper-proof |

### Policy Schema (v1)

5 sections: `boundaries` (read_only, no_access, allowed_paths), `operations` (blocked_commands, dependencies, git), `secrets` (enabled, action, custom_patterns), `quality` (pre_commit, require_tests), `workflow` (phases, thresholds, human_review). Plus `audit` (events, retention_days).

Enforcement mapping: boundaries → PreToolUse Write|Edit|Read|Grep|Glob, operations → PreToolUse Bash, secrets → PreToolUse Write|Edit, quality → PreToolUse Bash (git commit), workflow → Stop hook, audit → PostToolUse all + SessionStart/End.

### Key Bugs Found & Fixed

- macOS `/tmp` → `/private/tmp` symlink breaks glob matching (all path comparisons need symlink-aware resolution)
- `[[ "$path" == $glob ]]` doesn't recursively match `**` — converted to prefix check
- `\s` in `grep -E` not POSIX on macOS — use `[[:space:]]`
- `eval` on policy commands is injection risk — use `bash -c`
- Org merge logic didn't apply `stricter_action` to leaf string values — fixed jq merge
- Preamble created state file for non-pipeline skills — fixed with blocklist

---

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
