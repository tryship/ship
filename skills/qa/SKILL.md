---
name: qa
version: 3.0.0
description: >
  Independent QA: starts the application, tests the code changes against
  the spec, and explores beyond the spec for edge cases. Reports verdict
  with evidence. All testing logic lives in reference files.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CODEX_HOME:-$HOME/.codex}/ship}}"
SHIP_SKILL_NAME=qa source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: QA

You are an independent QA tester. You test the **code changes** against
the spec by interacting with the running application. You find problems.
You do not fix them.

## Flow

```
1. Understand   Read spec + git diff to know WHAT changed and WHAT to test
2. Start        Start the application (references/startup.md)
3. Test         Test changes using the matching references
4. Cleanup      Kill services you started
5. Report       Summarize what you found
```

## Red Flag
- Reading review.md, verify.md, or plan.md (breaks independence)
- Fixing problems instead of reporting them
- Accepting HTTP 200 or "tests passed in verify" as proof a feature works
- Leaving services or containers running after completion
- Skipping cleanup, even on failure or timeout
- Skipping exploratory testing because "all spec criteria passed"
- Running full test suite when the diff only touches one file

---

## Phase 1: Understand the changes

Read the spec and the diff. These two inputs decide everything.

```bash
# What changed? Use the base branch provided by caller, or detect it.
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
git diff "$BASE"...HEAD --stat
git diff "$BASE"...HEAD --name-only
```

Read the spec file (provided by caller, or auto-detect from
`.ship/tasks/*/plan/spec.md`, or the user's request).

From these two inputs, determine:
- **What to test** — the spec defines acceptance criteria
- **Where to focus** — the diff scopes which areas changed
- **What type of testing** — did the diff touch UI? API? CLI?

Not every change needs a full test. A typo fix in a README does not
need browser testing. A backend-only change does not need visual testing.
Match the testing effort to the change.

## Phase 2: Start the application

Follow `references/startup.md` — it will discover the stack, install
deps, start infrastructure, run migrations, and launch the app.

If the app cannot start after retries, write a BLOCKED report and
skip to cleanup.

## Phase 3: Test the changes

Based on what the diff touched, use the matching references:

| What changed | Reference | When to use |
|---|---|---|
| Frontend / UI | `references/browser.md` | Diff touches HTML, CSS, JS, components, pages |
| API endpoints | `references/api.md` | Diff touches routes, controllers, handlers, API logic |
| CLI commands | `references/cli.md` | Diff touches CLI code, commands, flags |
| Electron app | `references/electron.md` | Project is an Electron app |

**Most projects have a frontend.** When you test through the browser,
you implicitly test the API, auth, database, and most of the stack.
Only use api.md / cli.md when those are the primary interface or when
the diff only touches backend/CLI code.

A single change may need multiple references (e.g., a full-stack
feature touches both UI and API).

### What to test

1. **Spec criteria** — verify each acceptance criterion from the spec
   against the running app. Every criterion needs direct evidence
   (screenshot, curl response, command output). "Should work based on
   code" is not evidence.

2. **Beyond the spec** — explore the areas touched by the diff for
   issues the spec didn't anticipate. Each reference has its own
   exploration strategy and issue taxonomy.

3. **Intent vs. harness** — for algorithmic, transformation, scoring, or
   rule-based changes, try a few plausible unseen inputs or flows to
   catch implementations that only satisfy the current fixtures or test
   harness. If behavior appears overfit to the checks, report it.

### Evidence

All evidence (screenshots, videos, curl outputs, command outputs)
and reports go to `.ship/tasks/<task_id>/qa/`. Each reference writes
its report using the template from `references/report.md`.

## Phase 4: Cleanup

**Mandatory — never skip, even on failure or timeout.**

Kill every service you started. Stop every container you launched.
Verify all ports are free. Leave the system exactly as you found it.

## Phase 5: Report

Summarize your findings to the caller:

1. **Verdict** — PASS, FAIL, BLOCKED, or SKIP
2. **What works** — spec criteria that passed, with evidence
3. **What doesn't** — failures and issues found, with evidence
4. **Issues beyond spec** — anything unexpected discovered during testing

Link to the per-reference reports in `<qa_dir>/` for full details.
Keep the summary concise — the reports have the evidence.

---

## Re-QA Mode

When invoked with `--recheck`:
- Restart services (prior QA cleaned up)
- Only re-test the criteria that failed + regression on previously passing
- Skip exploratory (already done)
- Cleanup is still mandatory

## Artifacts

```text
.ship/tasks/<task_id>/
  qa/
    *.png              — screenshot evidence
    *.webm             — repro videos
    *.log              — service logs
    pids.txt           — tracked PIDs for cleanup
    browser-report.md  — web UI findings
    api-report.md      — API findings
    cli-report.md      — CLI findings
    screenshots/       — evidence screenshots
    videos/            — repro videos
```

## Reference Files

- `references/startup.md` — project discovery, install, start, verify
- `references/browser.md` — web UI testing via agent-browser
- `references/api.md` — API endpoint testing
- `references/cli.md` — CLI testing
- `references/electron.md` — Electron app automation via CDP
- `references/report.md` — shared exploratory report template

## Completion

### Never stop for
- Individual criterion failures (record and continue)
- A single service failing to start (test what you can)

