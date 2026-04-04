# Write Spec — Investigation & Spec Authoring

How to investigate a codebase and write a spec. Used by the host agent
in Phase 2-3 of `/ship:design`.

## Overview

Write comprehensive specs assuming the next reader has zero context.
Document what you found, what you traced, and what must be true for
the task to be done. The spec is the contract — everything downstream
(plan, implementation, review, QA) flows from it.

## Investigation

**This is the most important phase. Do not rush it.**

Read the codebase systematically. Before writing the spec, you must
have recorded: entrypoint files, traced caller chain, traced consumer
chain, affected data structures/interfaces, existing tests, and
unresolved assumptions — each with file:line evidence.

### For bug fixes — trace the full data/call path:

1. **Start at the symptom.** Find the function that produces the wrong
   output or behavior. Read it.
2. **Trace BACKWARD (callers).** Who calls this function? With what
   arguments? Trace up to 2 levels up (stop if graph terminates).
   Use `grep -rn "functionName"` to find all call sites. Read each one.
3. **Trace FORWARD (consumers).** Who uses the output? At least 2 levels
   down (stop if graph terminates). Read those too.
4. **Search for existing defenses.** Before proposing a new guard or
   fix, search for code that already handles this problem:
   `grep -rn "relatedKeyword"`. If you find existing defenses, explain
   why they are insufficient — or reconsider your root cause.
5. **Check for the fix already applied upstream.** The most common
   planning error is finding a gap in function A, without noticing that
   function A's caller already compensates for it. Trace the full path.

### For new features — map the integration surface:

1. **Find analogous features.** Search for similar existing features.
   How are they wired in? What files do they touch?
2. **Trace the integration path.** Follow a similar feature from config ->
   registration -> runtime -> UI/API surface. Every file it touches is a
   candidate for your plan.
3. **Check for existing infrastructure.** Does the foundation you need
   already exist? Don't reinvent what's there.

### For all tasks:

- **Verify file existence** before proposing to create new files
  (`test -f "path"`). If it exists, propose extending it.
- **Search for existing tests** that assert the current behavior you
  plan to change (`grep -rn "oldValue" --include="*.test.*"`). These
  tests will break — list them in your plan.
- **Cross-reference all consumers** when defining schemas or interfaces.
  Grep for the type name and every field name. Build a complete
  inventory, not a partial one.

## Task too vague?

After investigation, check if any of these are missing from the task
description AND could not be inferred from code:
- **Target behavior** — what should change
- **Target surface** — which files, endpoints, or components
- **Success condition** — how to know it's done

If any are missing, ask user via AskUserQuestion before writing spec.

## Write the Spec

Write your spec.md following brainstorming style — **flexible sections
scaled to the task's complexity.** A small bugfix gets a few paragraphs.
An architectural change gets full sections.

### What to include (pick what's relevant)

- **Problem/Motivation** — what's broken, missing, or suboptimal
- **Design approach** — how you'll solve it and why this approach
- **Investigation findings** — what you traced, file:line refs, what
  existing code you found, what assumptions remain unverified
- **Changes by file** — which files are affected and what changes
- **Intent / non-goals / forbidden shortcuts** — when relevant, state what
  counts as satisfying the task versus merely satisfying the current tests
- **Acceptance criteria** — concrete, testable conditions for "done"
- **Test plan** — what tests exist, what breaks, what's needed
- **Risks / unknowns** — anything you couldn't verify from code alone

### Spec self-review

After writing, run this checklist:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections? Fix them.
2. **Internal consistency:** Do sections contradict each other?
3. **Scope check:** Focused enough for a single plan?
4. **Ambiguity check:** Could any requirement be interpreted two ways?
   If so, pick one and make it explicit.
5. **Integrity check:** If tests could be gamed, does the spec say what
   behavior is required and which shortcuts are forbidden?

Fix issues inline. No need to re-review — just fix and move on.
