---
name: learn
version: 1.0.0
description: >
  Capture learnings from sessions to prevent repeating mistakes.
  Reflects on what went wrong or was discovered, routes each learning
  to the right store (conventions, hookify, design doc, or staging).
  Use when: learn, what did we learn, capture learning, session retro,
  avoid this mistake, remember this.
  Auto-invoked at the end of /ship:auto pipelines.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CODEX_HOME:-$HOME/.codex}/ship}}"
SHIP_SKILL_NAME=learn source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Learn

Every session makes the harness stronger. This skill captures what
was discovered or went wrong and routes it to the right persistent
store so future sessions don't repeat the same mistakes.

**Learnings staging file:** `.learnings/LEARNINGS.md`

This file is a **staging area**, not a permanent store. Learnings that
prove durable get promoted to permanent stores and removed from staging.
Learnings that are transient or wrong get pruned.

## Red Flag

**Never:**
- Capture obvious or trivial learnings ("npm install installs packages")
- Capture transient errors (network blips, rate limits, one-time CI flakes)
- Let the staging file grow beyond ~30 entries — prune or promote
- Promote a learning without verifying it against current code
- Skip the routing step — every learning belongs in a specific store

---

## Detect Mode

Parse the input to determine which mode to run:

- `/ship:learn` (no arguments, or end of auto pipeline) → **Capture** (includes auto-promote and auto-prune)
- `/ship:learn show` → **Show** current staging entries and their status

---

## Mode: Capture

Reflect on the current session and capture learnings.

### Step 1: Reflect

Review the conversation for:
- **Mistakes made** — wrong approach tried, then corrected
- **Surprises** — code behaved differently than expected
- **Project quirks** — build flags, env setup, timing, ordering requirements
- **Patterns that worked** — approaches that should be repeated
- **User corrections** — things the user told you to do differently

The test for each: **would knowing this save 5+ minutes in a future session?** If not, skip it.

### Step 2: Route

For each learning, classify where it belongs:

| Learning type | Destination | Example |
|---|---|---|
| Code constraint requiring AI judgment | `.ship/rules/CONVENTIONS.md` | "Don't simplify auth flows to fix errors" |
| Deterministic check (grep/regex can catch) | Hookify rule | "Never commit files matching *.env*" |
| Architectural decision or boundary | Design doc (`docs/design/`) | "Services A and B must not share a database" |
| Operational knowledge (everything else) | `.learnings/LEARNINGS.md` (staging) | "CI test X is flaky — retry before filing bug" |

### Step 3: Write

**For convention rules:** append to `.ship/rules/CONVENTIONS.md` using the existing format:
```markdown
## <Rule name>
Scope: <glob pattern>
Constraint: <what must not happen>
Why: <what breaks>
Source: learned from session <date>
```

**For hookify rules:** invoke `Skill("hookify:writing-rules")` and generate the rule file.

**For design docs:** invoke `Skill("write-design-docs")` if the learning is substantial enough for a design doc. Otherwise append to an existing design doc's Boundaries section.

**For staging (operational knowledge):** append to `.learnings/LEARNINGS.md`:
```markdown
## [LRN-YYYYMMDD-NNN] <type>

**Logged**: <ISO 8601 timestamp>
**Priority**: high | medium | low
**Status**: pending | promoted | pruned
**Area**: <infra | code | ci | qa | design | ops>

### Summary
<One sentence — the core insight>

### Details
<What happened, why it matters, what the impact was>

### Suggested Action
<What to do differently next time>

### Metadata
- Source: <session_observation | user_feedback | auto_detected>
- Related Files: <file paths>
- Tags: <relevant tags>

---
```

**ID format:** `LRN-YYYYMMDD-NNN` where NNN is a zero-padded sequence
number for that day. Check existing entries to avoid duplicates.

**Type:** one of: `correction`, `pattern`, `pitfall`, `quirk`, `preference`

Create `.learnings/LEARNINGS.md` if it doesn't exist.

### Step 4: Auto-promote on capture

When writing a learning, check if it should go directly to a permanent
store instead of staging. Promote immediately (no staging) when:

- The learning is clearly a code constraint → write to CONVENTIONS.md
- The learning is clearly a deterministic check → generate hookify rule
- The learning matches an existing design doc's scope → append to that doc's Boundaries

Only stage to `.learnings/LEARNINGS.md` when the classification is ambiguous or
the learning is operational (build quirks, timing, CI behavior, etc.).

---

## Auto-Promote (runs during capture)

When adding new learnings, also scan existing staging entries:

### Promote detection

An entry is ready for promotion when:
- **Repeated**: the same insight was captured again (validates it)
- **Aged + still valid**: older than 14 days AND the scope files still exist AND not already covered by CONVENTIONS.md or a design doc
- **Pattern match**: the entry clearly fits CONVENTIONS.md format (has a scope + constraint + why)

Auto-promote: move to the matching permanent store, remove from staging.

### Prune detection

An entry should be removed when:
- **Scope invalid**: the files/directories in Scope no longer exist
- **Redundant**: already covered by a CONVENTIONS.md rule, hookify rule, or design doc
- **Stale**: older than 30 days and never repeated or validated
- **Contradicted**: a newer learning or code change contradicts it

Auto-prune: remove from staging silently.

### Safety

- Never auto-promote to CONVENTIONS.md if the rule would contradict an existing rule
- Never auto-prune a learning that was added in the current session
- Log all promotions and prunes in the Execution Handoff output so the user can review

---

## Mode: Show

Display current learnings grouped by status.

Read `.learnings/LEARNINGS.md` and present:
- Recent (< 7 days)
- Promotion candidates (> 14 days, still valid)
- Prune candidates (scope invalid, redundant, or > 30 days)

---

## Session Start Integration

`.learnings/LEARNINGS.md` is injected into every session by `session-start.sh`
alongside CONVENTIONS.md and DESIGN_INDEX.md. This gives the AI
context about recent operational discoveries without manual lookup.

## Execution Handoff

Output summary:

```
[Learn] Session captured.
  New learnings: <N>
  Routed to:
    - CONVENTIONS.md: <N> rules added
    - Hookify: <N> rules generated
    - Design docs: <N> updated
    - Staging: <N> entries added
  Auto-promoted: <N> staging entries → permanent stores
  Auto-pruned: <N> stale/redundant entries removed
  Staging: <N> entries remaining
```
