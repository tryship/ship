---
name: setup
version: 1.0.0
description: >
  Bootstrap repo infrastructure and AI harness. Detects languages and tooling,
  installs missing tools, configures CI/CD and pre-commit hooks, discovers
  semantic constraints from code and git history, generates AGENTS.md and
  CONVENTIONS.md, and sets up hookify safety rules. Audits existing harness
  for staleness if one already exists.
  Use when: setup, init, bootstrap, setup harness, setup infra, install tools,
  configure CI, add pre-commit, enforce conventions.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Ship: Setup

## Preamble (run first)

```bash
SHIP_SKILL_NAME=setup source ${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

## Hard Rules

1. Detect first, never assume. Never invent a default stack.
2. One user interaction for infra module selection.
3. Execute ONLY the modules the user selected.
4. Respect existing config. Show diff and ask before replacing.
5. Read the code before writing any convention rules.
6. CONVENTIONS.md is for semantic rules only — things that require AI
   judgment. Deterministic checks (regex/grep) go in the pre-commit hook.
7. Do not include style rules. The model follows project style by
   reading the code. Do not include rules the linter already enforces.
8. Two user interactions max for harness: convention confirmation
   and existing file replacement (only if AGENTS.md or CONVENTIONS.md exists).
   Hooks are automatic — hookify for deterministic, ship plugin for semantic.

---

## Phase 1: Detect (automatic)

No user interaction in this phase.

### Step A: Pre-flight

- Check `git` is available. If missing, stop.
- Check whether cwd is a git repo with `git rev-parse --is-inside-work-tree`.
- If not a repo, run `git init`.

### Step B: Language + Package Manager

Scan repo files, then verify package manager / build tool exists on PATH.

| Language | File markers | Package manager / tool check |
|---|---|---|
| TypeScript / JavaScript | `package.json`, `tsconfig.json`, `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `npm`, `pnpm`, `yarn`, `bun` |
| Python | `pyproject.toml`, `requirements*.txt`, `setup.py`, `*.py` | `uv`, `poetry`, `pip`, `pip3` |
| Java | `pom.xml`, `build.gradle*`, `*.java` | `mvn`, `gradle` |
| C# | `*.csproj`, `*.sln`, `*.cs` | `dotnet` |
| Go | `go.mod`, `*.go` | `go` |
| Rust | `Cargo.toml`, `*.rs` | `cargo` |
| PHP | `composer.json`, `*.php` | `composer` |
| Ruby | `Gemfile`, `*.rb` | `bundle`, `gem` |
| Kotlin | `build.gradle*`, `settings.gradle*`, `*.kt` | `gradle`, `mvn` |
| Swift | `Package.swift`, `*.swift`, `*.xcodeproj` | `swift`, `xcodebuild` |
| Dart / Flutter | `pubspec.yaml`, `*.dart` | `dart`, `flutter` |
| Elixir | `mix.exs`, `*.ex`, `*.exs` | `mix` |
| Scala | `build.sbt`, `*.scala` | `sbt`, `mill` |
| C / C++ | `CMakeLists.txt`, `Makefile`, `*.c`, `*.cc`, `*.cpp`, `*.h`, `*.hpp` | `cmake`, `make`, detected compiler |
| Shell | `*.sh`, `*.bash` (no manifest) | `bash`, `shellcheck` (optional) |

If no language from the table above is detected, the repo may be
documentation-only, config-only, or use an unsupported language.
In that case: skip Install Tools and Pre-commit Hooks modules in
Phase 2 (mark as `n/a`), and proceed directly to Phase 3.5.

### Step C: Toolchain Detection

For each detected language, scan all mainstream tools by category:
linter, formatter, type checker, test runner.

Status per tool:
- `ready`: executable and config are usable as-is
- `missing`: repo has no configured tool for that category
- `broken`: config references unavailable or misconfigured tool

Reference: `references/toolchain-matrix.md` for the full detection matrix.

### Step D: Existing Configuration

Check and store:
- `.gitignore`
- `.github/workflows/*.{yml,yaml}`
- `.github/dependabot.yml`
- Pre-commit config: check `git config --get core.hooksPath`, `.ship/hooks/`;
  also detect legacy: `.husky/`, `.pre-commit-config.yaml`, `lint-staged` in package.json

## Phase 2: Choose (1 user decision)

Use AskUserQuestion after detection. The prompt must show:

- Detection results by language and tool, including `ready` / `missing` / `broken`
- Available modules (mark as `n/a` if no supported language detected):

```
Select modules to configure:

  1. [x] Install missing tools (linter, formatter, type checker)
  2. [x] Pre-commit hooks (lint + format on commit)
  3. [ ] CI/CD (GitHub Actions — workflow only, no Dependabot)
  4. [ ] Dependabot (dependency update PRs)
  5. [ ] AI Code Review
```

Options:
- A) Install all recommended
- B) Custom selection (specify numbers)
- C) Skip — I'll configure manually

## Phase 3: Execute modules

**Hard rule:** Execute ONLY the modules the user selected. Each module
is independent. CI/CD does NOT include Dependabot unless module 4 is
also selected.

| Module | Reference |
|---|---|
| Install Tools | `references/tooling.md` |
| Pre-commit Hooks | generate hook scripts in `.ship/hooks/`, set `core.hooksPath`, works across all worktrees |
| CI/CD | `references/ci.md` (generate workflow only, skip Dependabot/labeler sections unless those modules are also selected) |
| Dependabot | `references/ci.md` (Dependabot section only) |
| AI Code Review | `references/review.md` |

### Pre-commit hook configuration

Generate hook scripts in `.ship/hooks/` and set `core.hooksPath` so
hooks work across all worktrees and branches without per-worktree setup.

If `core.hooksPath` is already set to a path other than `.ship/hooks/`,
ask the user before overwriting it.

```bash
mkdir -p .ship/hooks
git config core.hooksPath .ship/hooks
```

Generate `.ship/hooks/pre-commit` with two sections:

1. **Deterministic safety checks** — grep/regex rules from Phase 5
   (type: deterministic). These catch things mechanically.
2. **Lint + format** — run the project's linter/formatter on staged files.

The script must be executable (`chmod +x`).

The script has two sections:
1. **Lint + format** — run the project's detected linter/formatter
   on staged files. Use `lint-staged` if configured. Only add wiring,
   not new tools (unless Install Tools was also selected).
2. **Safety checks** — grep/regex from Phase 5 deterministic findings
   (secrets, protected files, forbidden patterns).

If the project already uses `.husky/` or `.pre-commit-config.yaml`,
migrate to `.ship/hooks/`: port the existing hook commands into the
generated script, then remove the legacy config. Ask the user before
removing legacy files.

After each module, commit atomically:
```
git add <changed files>
git commit -m "<conventional commit message>"
```

---

## Phase 3.5: Harness Audit (only if harness already exists)

Before generating anything, check if the project already has harness
files (AGENTS.md, `.ship/rules/CONVENTIONS.md`, DEVELOPMENT.md, README.md).

If no harness files exist → skip to Phase 4 (full init).

If harness files exist → audit them for freshness using
`references/harness-audit.md`, then present results to the user:

Options:
- A) Fix stale claims and keep accurate ones (recommended)
- B) Regenerate everything from scratch
- C) Skip — don't touch existing harness

If A: update only the stale parts, preserve everything that's still
accurate. Proceed to Phase 4-7 to discover any NEW conventions not
yet covered.

If B: treat as full init — proceed to Phase 4 as if no harness exists.

If C: skip Phase 4-7 entirely.

## Phase 4: Survey

Do NOT read file contents yet. Reuse language/structure data from Phase 1.

### Step A: Monorepo detection

If Phase 1 revealed multiple sub-projects (each with their own manifest
file, separate language, or independent directory structure), this is
a monorepo.

For monorepos, identify sub-projects and their recent activity:

```bash
# Count commits per top-level directory in the last 30 days
git log --since="30 days ago" --name-only --pretty=format: | \
  grep -v '^$' | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -10
```

Record each sub-project: path, language, manifest file, commit count.

### Step B: Identify entry points

**Single repo with application code:** record main entry file and key call paths.
**Monorepo:** record entry point per active sub-project.
**No clear entry point** (library, plugin, config-only, shell scripts):
use the most-modified files in the last 30 days as starting points for
investigation. Run:
```bash
git log --since="30 days ago" --name-only --pretty=format: | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -10
```

---

## Phase 5: Investigate

Find rules that **only AI can judge** — things where violating them
causes bugs, security issues, or architectural breakage, but a regex
or linter cannot detect the violation.

Do NOT look for code style patterns (naming, formatting, import order).
The model already understands those from reading the code. Instead, look
for **constraints that the model would violate because it lacks context**.

**Monorepo:** investigate each active sub-project independently.

### Method A: Code investigation

Trace from entry points (or most-active files) 2-3 levels deep.
Look for:

- **Hidden contracts** — functions that look simple but have
  preconditions, side effects, or ordering requirements not obvious
  from the signature
- **Architectural boundaries** — layers or modules that must not
  be bypassed, but the code doesn't enforce it (no linter rule)
- **Security-sensitive paths** — auth flows, permission checks,
  data sanitization where removing or simplifying would cause a
  vulnerability
- **Domain-specific traps** — business logic that looks like it
  could be simplified but cannot (e.g., price in cents not dollars,
  timezone handling, regulatory constraints)

### Method B: Git history investigation

Scan git history for evidence of past mistakes:

```bash
# Find reverted commits (things that were tried and failed)
git log --oneline --grep="revert" --since="6 months ago" | head -10

# Find bug fix commits (what went wrong before)
git log --oneline --grep="fix" --grep="bug" --all-match --since="6 months ago" | head -10

# Find files with the most bug fixes (error-prone areas)
git log --oneline --grep="fix" --since="6 months ago" --name-only --pretty=format: | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -10
```

For interesting reverts or bug fixes, read the commit diff to
understand what constraint was violated.

### Filter

For each finding, apply this test:

1. **Can a regex/grep catch this?** → hookify rule (real-time PreToolUse
   block) + pre-commit hook (commit-time safety net)
2. **Can the model figure this out by reading the code?** → skip it
3. **Only AI with project context can judge this?** → CONVENTIONS.md

Examples of what goes WHERE:

Deterministic examples: protect .env files, block DROP TABLE, protected file paths.
Semantic examples: don't remove auth to fix errors, price in cents not dollars, legacy module migration.

---

## Phase 6: Confirm

Use AskUserQuestion. Present safety rules and semantic rules separately.
Ask if user has additional constraints not visible in the code.

Options: A) Generate as shown, B) Edit, C) Cancel.
Max two rounds of edits.

If user adds a convention without code evidence, search for it first.
If no evidence found, include as `Source: user-defined`.

---

## Phase 7: Generate

### Step A: Generate AGENTS.md

Read `references/agents-md.md` for structure. Fill from Phase 4-6
findings (survey, investigation, and user-provided context).
Omit sections with no content. Keep under 200 lines per file.

AGENTS.md includes ALL discovered conventions.

**Single repo:** generate or update root `AGENTS.md`.

**Monorepo:** update each sub-project's local `AGENTS.md` with that
sub-project's conventions. If a local AGENTS.md doesn't exist, create it.
Root AGENTS.md gets repo-wide conventions only (commit format, shared
tooling, cross-project boundaries). Sub-project-specific conventions
go in the sub-project's AGENTS.md.

**If an `AGENTS.md` already exists**, use AskUserQuestion:

```
AGENTS.md already exists. Here's what would change:

<show diff summary: sections added/changed/removed>
```

Options:
- A) Replace with new version
- B) Merge — add new sections, keep existing content
- C) Skip — don't touch AGENTS.md

For monorepos, ask once per file that needs changes (batch into one
AskUserQuestion if possible).

### Step B: Generate CONVENTIONS.md

Write to `.ship/rules/CONVENTIONS.md`. This file contains ONLY rules
that require AI semantic judgment. Deterministic checks go in the
pre-commit hook, NOT here.

**Test before including:** "Could a regex or grep catch this violation?"
If yes, it belongs in the pre-commit hook. CONVENTIONS.md is for things
like "don't remove auth logic to fix a bug" — where understanding
intent is required.

Format:

```markdown
## <Rule name>
Scope: <glob pattern>
Constraint: <what must not happen>
Why: <what breaks — bug, security issue, data loss, etc.>
Source: <observed from code | git-history commit:hash | user-defined>
```

Example:

```markdown
## Do not simplify auth flows to fix errors
Scope: src/auth/**
Constraint: Never remove or bypass auth checks to resolve runtime errors.
Why: AI agents are known to delete validation logic to make errors go away.
Source: observed from code
```

Do NOT include style rules — the model follows style by reading code.

**If `.ship/rules/CONVENTIONS.md` already exists**, use AskUserQuestion:

```
.ship/rules/CONVENTIONS.md already exists with <N> conventions.
```

Options:
- A) Replace entirely with new conventions
- B) Merge — add new conventions, keep existing ones
- C) Skip — don't touch CONVENTIONS.md

### Step C: Generate hookify safety rules

#### Ensure hookify is installed

Check if hookify plugin is available:
```bash
ls ~/.claude/plugins/data/*/hookify 2>/dev/null && echo "HOOKIFY_FOUND" || echo "HOOKIFY_NOT_FOUND"
```

If not found, install it:
```bash
claude /plugin install hookify
```

If install fails (e.g., no internet), warn the user but continue —
pre-commit hook still provides commit-time safety. Hookify is the
real-time layer, not the only layer.

#### Generate rule files

For each deterministic finding, write `.claude/hookify.ship-<name>.local.md`:

```markdown
---
name: ship-protect-env
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env$
action: block
---

Do not edit .env files directly.
```

Use `event: bash` for command-level rules. Hookify auto-discovers
`.claude/hookify.*.local.md` files — no restart needed.

Also mirror these checks in `.ship/hooks/pre-commit` as a safety net.

Semantic rules (CONVENTIONS.md) are injected at session start by the
ship plugin's SessionStart hook — no per-edit checking needed.

### Step D: Update .gitignore

Generate a comprehensive `.gitignore` based on everything detected in
Phase 1 (languages, package managers, toolchains, IDEs, build tools).

Use your knowledge of each detected technology to add the standard
ignore patterns — caches, build output, virtual environments, IDE
config, OS files, dependency directories, log files, environment
variables, etc. Cover all detected languages and tools thoroughly.

**Always include these Ship-specific rules:**
```
# Ship runtime (tasks and audit are ephemeral)
.ship/tasks/
.ship/audit/
```

Do NOT gitignore `.ship/rules/`, `.ship/hooks/`, or `.ship/scripts/`.

**Always include Claude Code rules:**
```
.claude/*
!.claude/settings.json
!.claude/hookify.ship-*.local.md
```

**For existing repos:** read the current `.gitignore`, identify gaps
based on detected tech stack, and append missing sections. Do not
duplicate or reorder existing rules.

### Step E: Commit

Stage all generated/modified files and commit with a conventional
commit message summarizing what was generated.

---

## Completion

Always output this format:

```
[Setup] Complete.

Infrastructure:
  - <module name> — <what was done>

Harness:
  AGENTS.md: <generated | merged | skipped>
  CONVENTIONS.md: <N> semantic rules
  Hookify: <N> safety rules generated
  Pre-commit: <configured | skipped>

  Semantic rules:
    1. <name> — <why>
    2. <name> — <why>
  Safety rules:
    1. <name> — <what it blocks>
    2. <name> — <what it blocks>
```

## Reference Files

- `references/agents-md.md` — AGENTS.md structure guide
- `references/toolchain-matrix.md` — full detection matrix for 14 languages
- `references/tooling.md` — tool installation instructions per language
- `references/ci.md` — GitHub Actions CI/CD generation
- `references/review.md` — AI code review workflow setup
- `references/runtime-install-guide.md` — platform-specific runtime installation
- `references/harness-audit.md` — harness freshness audit (Phase 3.5)

<Bad>
- Putting style rules in CONVENTIONS.md
- Putting grep-able checks in CONVENTIONS.md instead of hookify/pre-commit
- Generating rules from templates without reading code
- Running Dependabot inside CI/CD module
- Overwriting existing core.hooksPath without asking
</Bad>
