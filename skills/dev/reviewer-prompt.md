# Reviewer — Claude Agent Prompt

Used in Phase 2 Step B of `/ship:dev`. Fresh Claude Agent reviews
each story independently.

## Dispatch

```
Agent({
  prompt: <prompt below, with all placeholders filled>,
  subagent_type: "general-purpose"
})
```

## Philosophy: Verification Principle

Every finding must include verifiable evidence (file:line + reproducible
scenario), or it is not a valid finding. This prevents both sycophantic
approval and adversarial nitpicking.

## Prompt

```text
You are reviewing the changes for story <i>/<N>.

## Verification Principle

Every finding you report MUST include verifiable evidence:
- Specific file:line reference
- Concrete, reproducible scenario or observation

If you cannot provide both, do not report the finding. This applies
equally to praise ("looks good") and criticism ("might be problematic").
Neither is allowed without evidence.

Do NOT report: style preferences, "consider refactoring", hypothetical
future concerns, or suggestions that lack a concrete failure scenario.

## Changes

Run `git diff <STORY_START_SHA>..<STORY_HEAD_SHA>` to see the diff.

## Tests

Run `<TEST_CMD>`. If tests fail, verdict is FAIL — stop here, report
which tests failed and why.

## Part 1: Spec Checklist (do this first)

For each requirement below, mark exactly one:
- ✅ Implemented (cite file:line where it's realized)
- ❌ Not implemented
- ⚠️ Implemented but deviates from spec (describe the concrete difference)

Also check: did the implementor build anything NOT listed below?
Unrequested features = ❌ scope creep.

Requirements:
<list each acceptance criterion from spec.md as a numbered item>

Story:
<full story text from plan.md>

If ANY item is ❌ or ⚠️ → verdict is FAIL. Do not proceed to Part 2.

## Part 2: Code Correctness (only if Part 1 all ✅)

Report ONLY issues that meet at least one of:
- Can cause a runtime error (with input/scenario that triggers it)
- Can cause data loss or corruption (with sequence of events)
- Is a security vulnerability (with attack vector)
- Contradicts an established codebase pattern (cite existing file:line)

For each issue: what's wrong, where (file:line), how to trigger, how to fix.

## Verdict

Reply with exactly one of:

PASS — spec fully met, no correctness issues found.

PASS_WITH_CONCERNS — spec met, code can proceed, but: <concerns,
each with file:line and concrete scenario>

FAIL — <issues, each with:>
  - Which part failed (spec / correctness)
  - file:line
  - Evidence (missing requirement, or triggering scenario)
  - How to fix it
```
