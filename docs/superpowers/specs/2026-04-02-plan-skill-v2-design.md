# Plan Skill v2 — Parallel Investigation, Brainstorming Specs, Executable Plans

**Goal:** Redesign the plan skill so spec.md follows superpowers:brainstorming style (flexible, scaled to complexity) and plan.md follows superpowers:writing-plans style (bite-sized TDD tasks with complete code), with parallel Codex investigation for truly independent adversarial validation.

**Architecture:** Two-phase skill — Phase 1 (Design) produces spec.md via parallel Claude + Codex investigation and diff; Phase 2 (Write Plan) translates the merged spec into an executable plan.md and validates it via Codex execution drill.

---

## Problem

The current plan skill (v0.3.0) has three issues:

1. **spec.md and plan.md are too similar.** The rigid spec template (Background/Problem/Why now/Context/Non-goals/Acceptance Criteria) overlaps heavily with plan.md's content. Both end up describing the same thing in slightly different words.

2. **Codex Plan B is weaker than Plan A.** Codex receives only the task description — no investigation instructions, no shared methodology. Its "independent plan" is shallow compared to Claude's investigated plan, making the diff phase less valuable.

3. **Spec format is too rigid.** The heavy template forces every task through the same structure regardless of complexity. A typo fix gets the same "Why now" section as an architecture change.

## Design

### Two Phases, Two Artifacts

**Phase 1: Design** — Produce spec.md

Both Claude and Codex receive the same investigation instructions and the same task description. Both independently investigate the codebase and produce a spec. Claude diffs the two specs, resolves divergences by code evidence, and writes the final spec.md.

spec.md follows superpowers:brainstorming style:
- Flexible body sections scaled to complexity
- Problem/motivation, design approach, changes by file, test plan — but only the sections that matter for this task
- No rigid template — a small bugfix gets a few paragraphs, an architectural change gets full sections
- Self-reviewed for TBDs, contradictions, ambiguity

**Phase 2: Write Plan** — Produce plan.md

Claude translates the validated spec.md into an executable plan. Codex validates the plan via execution drill.

plan.md follows superpowers:writing-plans style:
- Header with goal/architecture/tech stack
- Bite-sized tasks with checkbox steps (2-5 min each)
- TDD: write failing test, verify fail, implement, verify pass, commit
- Exact file paths, complete code blocks, exact commands with expected output
- No placeholders ever — every step contains the actual content

### Parallel Investigation Flow

```
1. Init (resolve task_id, create dirs)
2. Dispatch Codex MCP — same investigation instructions, same task
3. While Codex works: Claude investigates and writes spec.md
4. Read Codex result
5. Diff the two specs, resolve divergences by code evidence
6. Write plan.md from merged spec
7. Dispatch Codex execution drill on plan.md
```

Step 2-3 run in parallel: Codex is dispatched first (async MCP call), then Claude does its own investigation. When Claude finishes its spec, it reads Codex's result and diffs.

### What This Replaces

| Before (v0.3.0) | After (v2) |
|---|---|
| Rigid spec.md template (Background/Problem/Why now/Context/Non-goals) | Flexible brainstorming-style spec — sections scaled to complexity |
| Vague plan.md ("steps with file:line refs") | Writing-plans-style plan — TDD, checkbox steps, complete code |
| Codex gets only task description, no investigation | Codex gets same investigation instructions as Claude |
| Sequential: Claude investigates, writes spec, THEN Codex writes Plan B | Parallel: Codex dispatched first, Claude investigates simultaneously |
| User approval gate inside plan skill | Removed — `/ship:auto` owns approval |

### What Stays the Same

- Investigation is the most important phase — Claude reads all code it references
- Codex never sees Claude's spec when producing its own (independence is sacred)
- Divergences resolved by code evidence, not argument
- Execution drill must pass before plan is marked ready
- Hard rules, quality gates, error handling patterns
- Integration with `/ship:auto` and `/ship:dev`
- Artifacts live in `.ship/tasks/<task_id>/plan/`

### Reference Files

Two new reference files replace the current ones:

| Old | New | Purpose |
|---|---|---|
| `independent-planner.md` | `independent-investigator.md` | Codex prompt for Phase 1 — same investigation methodology as Claude, produces spec in brainstorming format |
| `execution-drill.md` | `execution-drill.md` (updated) | Codex prompt for Phase 2 — validates plan.md steps are implementable, checks writing-plans format compliance |

`independent-investigator.md` gives Codex the same investigation instructions that appear in the skill's Investigation phase — specifically:

- For bug fixes: start at symptom, trace backward (callers, 2+ levels), trace forward (consumers), search for existing defenses, check if fix already applied upstream
- For new features: find analogous features, trace integration path (config → registration → runtime → UI/API), check for existing infrastructure
- For all tasks: verify file existence, search for existing tests, cross-reference all consumers

The only difference from Claude's instructions: after investigation, Codex outputs a brainstorming-style spec (not a plan). Codex never sees Claude's spec.

### Downstream Impact

- `/ship:dev` reads spec.md for acceptance criteria — no change needed, brainstorming-style specs still have acceptance criteria (in flexible form)
- `/ship:review` reads spec.md for intent — brainstorming-style is richer context
- `/ship:auto` Phase 3 (user approval) — reads spec.md + plan.md, presents summary. No change to auto's flow, just better artifacts to summarize.

## Changes by File

### `skills/plan/SKILL.md`
- Rewrite Phase 3 (Write Plan A) to describe brainstorming-style spec.md format
- Add new Phase 3.5 (Write plan.md) with writing-plans format
- Update Phase 4 (Codex) to dispatch at start of investigation (parallel), not after spec is written
- Update Phase 5 (Diff) to compare two specs in brainstorming format
- Update Phase 6 (Drill) to validate writing-plans format compliance
- Remove user approval gate from completion section
- Remove rigid spec.md and plan.md templates
- Update quality gates table
- Bump version to 1.0.0

### `skills/plan/independent-investigator.md` (new, replaces `independent-planner.md`)
- Same investigation methodology as SKILL.md Phase 2
- Same spec output format (brainstorming style)
- MCP call parameters

### `skills/plan/execution-drill.md` (updated)
- Validate writing-plans format: checkbox steps, TDD order, code blocks present
- Check file paths exist, line numbers match
- Check no placeholders (TBD, TODO, "similar to Task N")
- Verify spec coverage — every acceptance criterion has a task

### `skills/plan/independent-planner.md` (deleted)
- Replaced by `independent-investigator.md`

## Test Plan

### Manual verification
- Run `/ship:plan` on a small bugfix task — spec.md should be a few paragraphs, plan.md should have 1-2 tasks with TDD steps
- Run `/ship:plan` on a multi-file feature — spec.md should have full sections, plan.md should have 3+ tasks with complete code
- Verify Codex MCP is dispatched before Claude starts investigating (check timing in output)
- Verify Codex's spec follows same format as Claude's (brainstorming style)
- Verify plan.md has no placeholders, all code blocks are complete
- Run through `/ship:auto` end-to-end — confirm dev/review/qa can consume the new artifacts

### Format compliance checks
- spec.md: no rigid template sections (Background/Why now/Non-goals), flexible body
- plan.md: has header (Goal/Architecture/Tech Stack), tasks have checkbox steps, TDD order, commit steps
- diff-report.md: unchanged format
