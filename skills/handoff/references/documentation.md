# Documentation Workflow

Use this workflow whenever a task may change repository truth that future work relies on.

This file is a repo-agnostic SOP for documentation maintenance.

Its purpose is to keep instruction files, onboarding docs, deeper docs, local docs, and process docs aligned with the codebase so stale documentation does not bias future work.

## Mission

Keep the smallest useful set of repository documents accurate, discoverable, and safe to trust.

Treat stale documentation as a correctness problem. If future work follows the wrong instruction, the documentation is broken even if the code is correct.

## Repository Bindings

Before using this SOP in any repo, resolve these bindings from the actual repository:

- agent instructions file: `AGENTS.md` or equivalent
- root onboarding doc: `README.md` or equivalent
- deeper knowledge docs: `docs/` or equivalent
- local subsystem doc pattern: nearest local `README.md` or equivalent
- process or SOP doc pattern: repo-specific
- published documentation surfaces: docs sites, marketing sites, examples, changelogs, or equivalent
- command truth sources: `Makefile`, `justfile`, package manifests, scripts, task runners, CI config, or equivalent
- config truth sources: config structs, schemas, example env/config files, deployment manifests, or equivalent
- public API truth sources: exported package entrypoints, schemas, generated clients, protocol definitions, or equivalent

## Core Principle

Documentation should preserve durable knowledge, not archive every execution plan.

Use this rule:

- if the content should still guide future work after the current task is done, it may belong in the repo
- if the content mainly explains how to execute one current task, it usually does not belong in durable docs

## Ground Truth

When documentation and implementation disagree, verify against canonical truth sources:

- code paths
- tests
- config definitions
- command sources
- public package exports and supported import paths
- schema or protocol definitions for wire contracts
- deployment or runtime definitions
- current repo layout

Do not resolve uncertainty by guessing in prose.

## Ownership

Use the narrowest correct document.

1. Code, tests, config, scripts, and actual behavior are the ground truth.
2. The agent instructions file owns repo-wide guidance, global rules, and the top-level map.
3. The root onboarding doc owns onboarding, setup, run, test, and top-level repo structure.
4. The deeper docs area owns durable architecture, design, decisions, integrations, runbooks, and migrations.
5. Local subsystem docs own one subsystem, service, app, package, example, docs site, or published doc surface.
6. Process docs own repeatable procedures such as release, refactor, migration, and documentation maintenance.
7. Focused local docs own deep topics that are too detailed or too volatile for top-level docs.

If two docs conflict, trust the higher item in this order until the lower item is fixed.

## Decision Tree

Follow these questions in order:

1. Did the task change behavior, commands, config, naming, architecture, file layout, or workflow?
   If no, a doc update may not be needed.

2. Would a future human or agent need different instructions after this change?
   If yes, documentation must be updated.

3. Is the new truth primarily a repeatable procedure, workflow, migration, rollout, or operational process?
   If yes, update or create a process doc, even if the process is repo-wide.

4. Is the new truth global and stable?
   If yes, update the agent instructions file.

5. Is the new truth mainly about onboarding, setup, run, test, or top-level repo structure?
   If yes, update the root onboarding doc.

6. Is the new truth durable architecture, design, decisions, integrations, runbook knowledge, or a long-lived migration?
   If yes, update `docs/` or the repo's equivalent deeper doc area.

7. Is the new truth limited to one subsystem or directory?
   If yes, update the nearest local doc.

8. Does no current document fit cleanly?
   If yes, create a focused doc and link to it from the nearest entrypoint. Do not dump it into the top-level agent file.

## Change-Scoped Workflow

Use this checklist before declaring the task complete.

### 1. Map The Change

Look at the actual diff, not the intended task.

List which truths changed:

- behavior
- commands
- config
- naming
- architecture
- public API surface
- runnable examples or code snippets
- docs-site or website navigation
- file paths
- workflow steps

### 2. Route Each Changed Truth

For each changed truth, choose the owning document using the ownership rules and decision tree above.

Do not default to the top-level agent file. Update the most local correct document first.

### 3. Update The Minimum Correct Set

Make the smallest set of edits that restores truth.

If the same detail appears in multiple files, decide which file should own it and trim the others to short pointers where possible.

### 4. Remove Nearby Contradictions

Search nearby docs for stale names, old paths, removed commands, outdated architecture descriptions, and repeated claims that no longer match.

Do not leave easy, obviously conflicting statements behind.

### 5. Verify Against Repo Reality

Check documentation against the repo's canonical truth sources.

Verify:

- referenced files and directories exist
- commands match the current command sources
- config keys match actual config definitions
- names and terminology match the current repo and product
- repeated claims do not conflict across root docs, deeper docs, local docs, docs sites, and examples

Prefer mechanical checks when possible:

- use `rg` to find old names or removed commands
- compare commands against the repo's task runner and scripts
- compare config instructions against actual config files, schemas, or structs

### 6. Record The Result

Before finishing, explicitly state one of these:

- docs updated: list the files
- docs checked, no update needed
- doc debt logged in: list the sink and the missing truth

Do not silently skip documentation review.
