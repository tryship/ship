# AGENTS.md Template

Fill from Phase 1-2 findings. Omit empty sections. Under 200 lines.

---

## Project Overview

1-2 sentences: what this project is, tech stack.

## Commands

| Action | Command |
|--------|---------|
| Dev server | `<exact>` |
| Build | `<exact>` |
| Test | `<exact>` |
| Test single | `<exact>` |
| Lint | `<exact>` |
| Format | `<exact>` |
| Type check | `<exact>` |

Only rows with detected commands.

## Dev Environment

Setup from scratch: install deps, env vars, database, etc.
Only if non-trivial.

## Repository Map

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `<path>` | `<types>` | `<purpose>` |

Only directories that matter for code flow.

## Architecture

Key architectural constraints with evidence.
Only decisions found in the code, not wishlists.

## Code Style

Conventions that differ from language defaults.
GOOD/BAD examples with file:line references.
Skip linter-enforced patterns.

## Boundaries

### Always Do
- <from observed patterns>

### Never Do
- <from observed patterns>

Only boundaries with evidence.

## Testing

- Framework: `<detected>`
- Location: `<path>`
- Run all: `<command>`
- Run single: `<command>`

## PR and Workflow

From `.github/pull_request_template.md`, git log branch/commit patterns.
Omit for new or solo projects.

## Gotchas

Non-obvious patterns and platform-specific issues discovered during investigation.
