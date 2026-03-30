# Setup Skill Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `/setup` from a 730-line monolith into a ~120-line thin orchestrator + 3 reference modules, with 14-language detection and tier-based user choice.

**Architecture:** SKILL.md orchestrates 4 phases (Detect → Choose → Core → Modules). Core generates policy.json + AGENTS.md inline. Optional modules (tooling, CI, review) live in `references/` and are loaded on demand per user's tier choice.

**Tech Stack:** Markdown skill files, jq for policy manipulation, bash for detection/verification.

---

### Task 1: Rewrite SKILL.md — Thin Orchestrator

**Files:**
- Rewrite: `skills/setup/SKILL.md` (replace entire content)

- [ ] **Step 1: Write the new SKILL.md frontmatter + preamble**

Replace the entire `skills/setup/SKILL.md` with:

```markdown
---
name: setup
version: 1.0.0
description: |
  Bootstrap a repo for AI-ready development with Ship enforcement.
  Detects languages and tooling across 14 languages, generates security
  policy (ship.policy.json) and AI handbook (AGENTS.md). Optional modules
  install missing tools, configure CI/CD, and set up AI code review.
  Use when: "setup", "init", "bootstrap", "make repo AI-ready".
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

One command. Repo goes from bare to AI-ready with Ship enforcement active.

Detect existing tooling, generate security policy and AI handbook.
Optional: install missing tools, configure CI/CD, set up AI code review.

Idempotent — running twice skips already-configured items.

---

## Preamble

Bash("bash ${CLAUDE_PLUGIN_ROOT}/bin/preamble.sh setup")

---
```

- [ ] **Step 2: Write Phase 1 — Detect**

Append to SKILL.md:

```markdown
## Phase 1: Detect (automatic)

No user interaction. Collect all data needed for Phase 2-4.

### 1.1 Pre-flight

Check git is available and current directory is a git repo:
- `which git` → if missing, tell user to install and stop
- `git rev-parse --is-inside-work-tree` → if not a repo, run `git init`

### 1.2 Language + Package Manager

Scan for file markers. For each detected language, verify the package
manager is available. Supported languages:

| Language | File Markers | PM Check |
|----------|-------------|----------|
| TypeScript/JS | `package.json`, `tsconfig.json` | npm / yarn / pnpm |
| Python | `pyproject.toml`, `setup.py`, `requirements.txt` | pip / uv |
| Java | `pom.xml`, `build.gradle` | mvn / gradle |
| C# | `*.csproj`, `*.sln` | dotnet |
| Go | `go.mod` | go |
| Rust | `Cargo.toml` | cargo |
| PHP | `composer.json` | composer |
| Ruby | `Gemfile`, `*.gemspec` | bundle / gem |
| Kotlin | `build.gradle.kts` + `*.kt` files | gradle |
| Swift | `Package.swift`, `*.xcodeproj` | swift |
| Dart/Flutter | `pubspec.yaml` | dart / flutter |
| Elixir | `mix.exs` | mix |
| Scala | `build.sbt` | sbt |
| C/C++ | `CMakeLists.txt`, `Makefile` | cmake / make |

### 1.3 Toolchain Detection

For each detected language, check **all mainstream tools** per category
(linter, formatter, type checker, test runner). Scan all config file
variants — use whichever the user already has. Only mark `missing` if
no tool exists for that category.

**Core principle: detect first, never assume. Respect existing configs.**

Read `references/toolchain-matrix.md` for the full detection matrix
(config files, verify commands, and defaults per language).

Each tool gets a status:
- `ready` — config exists AND tool can execute
- `missing` — no config for this category
- `broken` — config exists but tool fails (show error, don't write to policy)

Built-in tools (gofmt, rustfmt, cargo test, dart format, etc.) are
always `ready` if the language runtime exists.

### 1.4 Existing Configuration

Check for:
- `.ship/ship.policy.json` → policy exists
- `AGENTS.md` / `CLAUDE.md` → AI handbook exists
- `.gitignore` → gitignore exists
- `.github/workflows/*.yml` → CI exists
- `.github/dependabot.yml` → dependabot exists

Store all results in working memory for Phase 2.
```

- [ ] **Step 3: Write Phase 2 — Choose**

Append to SKILL.md:

```markdown
---

## Phase 2: Choose (1 user decision)

Present detection results and tier choice in a single AskUserQuestion.

Format:

    Re-ground: Setting up AI development environment for your project.

    Simplify: I scanned your codebase. Here's what I found — green means
    ready, red means not installed, yellow means has a problem.

    Languages: <detected>
    Package managers: <detected with ✓/✗>

    Toolchain:
      ✓ <tool> (<category>)
      ✗ <tool> (<category>) — not installed
      △ <tool> (<category>) — config exists but cannot run: <error>

    Existing config:
      ✓/✗ ship.policy.json
      ✓/✗ AGENTS.md
      ✓/✗ CI workflow
      ✓/✗ .gitignore

    ---

    A) Full setup (recommended)
       Install missing tools, configure CI, generate security policy
       and AI handbook. AI auto-checks quality, dangerous ops blocked.

    B) Basic setup
       Generate security policy and AI handbook only. No tools installed,
       no CI. Existing tools included in quality checks.

    C) Custom
       Choose which modules to configure.

    Any special notes AI should know about this project? (optional, Enter to skip)

If user picks C, show a follow-up AskUserQuestion:

    Modules (1-2 always included):
    1. [x] Security policy (ship.policy.json) — always
    2. [x] AI handbook (AGENTS.md) — always
    3. [ ] Install missing tools (<list>)
    4. [ ] CI/CD (GitHub Actions + Dependabot)
    5. [ ] AI Code Review (PR auto-review)

    Custom boundaries (files/dirs AI must never touch):
    Default: .env*, *.pem, *.key, credentials*, secrets/
    Additional paths? (optional, Enter to skip)
```

- [ ] **Step 4: Write Phase 3 — Core**

Append to SKILL.md:

```markdown
---

## Phase 3: Core (automatic)

Always runs regardless of tier choice.

### 3.1 Generate `.ship/ship.policy.json`

1. If `.ship/ship.policy.json` exists → show diff of proposed changes,
   ask user to confirm. Do NOT overwrite silently.
2. Read template: `templates/ship.policy.json`
3. Fill `quality.pre_commit` with **only `ready` tools** from Phase 1.
   Use the actual detected tool and command — if user has flake8,
   write `flake8`, not `ruff check .`
4. Fill `require_tests.source_patterns` and `test_patterns` per language
5. If C tier with custom boundaries → append to `no_access`
6. Use jq for all policy.json modifications

### 3.2 Generate `AGENTS.md`

1. If `AGENTS.md` exists → show diff, ask user to confirm
2. Read template: `templates/agents-md.md`
3. Fill with **actual detected commands**, not recommendations:
   - Commands: detected build/test/lint/format/typecheck
   - Repository Map: languages + directory structure
   - Code Style: read code samples, only note deviations from defaults
   - Boundaries: from policy.json no_access/read_only
   - Testing: detected test runner + config
   - Gotchas: user input from Phase 2 (if any)
4. Target: <200 lines
5. Show to user, ask: A) Confirm B) I want changes

### 3.3 Auxiliary

- Create `.ship/audit/` directory
- Update `.gitignore`: add `.ship/tasks/` and `.ship/audit/`
  (NOT `.ship/` — policy.json must be git-tracked)
- Atomic commit: `feat: generate ship policy and AGENTS.md`
```

- [ ] **Step 5: Write Phase 4 — Modules + Completion**

Append to SKILL.md:

```markdown
---

## Phase 4: Modules (per tier)

Tier A: execute all modules in order.
Tier B: skip to Done.
Tier C: execute only user-selected modules.

### Module: Install Tools
Read `references/tooling.md` and follow its instructions.
After install, update policy.json pre_commit and AGENTS.md commands.

### Module: CI/CD
Read `references/ci.md` and follow its instructions.

### Module: AI Code Review
Read `references/review.md` and follow its instructions.

---

## Done

Show outcome-oriented summary:

    Setup complete.

    Security:
      ✓ ship.policy.json — dangerous operations auto-blocked
      ✓ Secret scanning — .env / API keys auto-blocked on write
      ✓ Audit log — all AI operations logged to .ship/audit/

    Quality:
      ✓ <list of ready tools with categories>
      ✓ Pre-commit checks: <list of pre_commit commands>

    CI/CD: (if configured)
      ✓ GitHub Actions / Dependabot / AI Review

    Documentation:
      ✓ AGENTS.md (<N> lines)

    Next: /ship:auto "describe what you want to build"

Warnings for incomplete items:
    ⚠ <tool> config exists but cannot execute — fix manually, rerun /setup

## What Setup Does NOT Do

- Does not scaffold empty repos (init your project first)
- Does not configure deployment (use /setup-deploy)
- Does not modify source code (only config + docs)
- Does not replace existing tool configurations
- Does not install tools globally or use sudo
```

- [ ] **Step 6: Verify SKILL.md line count**

Run: `wc -l skills/setup/SKILL.md`
Expected: ~120-150 lines

- [ ] **Step 7: Commit**

```bash
git add skills/setup/SKILL.md
git commit -m "refactor(setup): rewrite as thin orchestrator (~120 lines)

Replace 730-line monolith with 4-phase orchestrator that delegates
optional modules to reference files. Single user decision point,
14-language detection, tier-based choice (Full/Basic/Custom)."
```

---

### Task 2: Create `references/toolchain-matrix.md`

**Files:**
- Create: `skills/setup/references/toolchain-matrix.md`

This file contains the complete detection matrix for all 14 languages. SKILL.md Phase 1.3 references it.

- [ ] **Step 1: Write the toolchain matrix reference**

Create `skills/setup/references/toolchain-matrix.md`:

```markdown
# Toolchain Detection Matrix

Complete detection rules for Phase 1.3. For each language, check all
config file variants in order. Use whichever the user already has.
Only mark `missing` if no tool exists for that category.

## Python

**Linter:**
- Check: `ruff.toml`, `pyproject.toml` has `[tool.ruff]`, `.flake8`, `setup.cfg` has `[flake8]`, `.pylintrc`, `pyproject.toml` has `[tool.pylint]`
- Verify: `<tool> --version`
- Default (if missing): ruff
- Install: `uv add --dev ruff` or `pip install ruff`

**Formatter:**
- Check: ruff format config (same as linter if ruff), `.style.yapf`, `pyproject.toml` has `[tool.black]`, `setup.cfg` has `[yapf]`
- Verify: `<tool> --version`
- Default: ruff format
- Install: (included with ruff)

**Type Checker:**
- Check: `pyrightconfig.json`, `pyproject.toml` has `[tool.pyright]`, `mypy.ini`, `.mypy.ini`, `pyproject.toml` has `[tool.mypy]`
- Verify: `<tool> --version`
- Default: pyright
- Install: `uv add --dev pyright` or `pip install pyright`

**Test Runner:**
- Check: `pyproject.toml` has `[tool.pytest]`, `pytest.ini`, `setup.cfg` has `[tool:pytest]`, `tests/` directory, `test_*.py` files
- Verify: `pytest --co -q 2>&1 | head -3`
- Default: pytest
- Install: `uv add --dev pytest pytest-cov` or `pip install pytest pytest-cov`

## TypeScript / JavaScript

**Linter:**
- Check: `eslint.config.*` (js/mjs/cjs/ts), `.eslintrc.*` (js/json/yml/yaml), `biome.json`, `biome.jsonc`
- Verify: `npx eslint --version` or `npx biome --version`
- Default: eslint
- Install: `npm install -D eslint`

**Formatter:**
- Check: `.prettierrc`, `.prettierrc.*` (js/json/yml/yaml), `package.json` has `"prettier"`, `biome.json` (also formats), `dprint.json`
- Verify: `npx prettier --version` or `npx biome --version`
- Default: prettier
- Install: `npm install -D prettier`

**Type Checker:**
- Check: `tsconfig.json` (look for `"strict": true`)
- Verify: `npx tsc --version`
- Default: tsc with strict mode
- Install: `npm install -D typescript`

**Test Runner:**
- Check: `vitest.config.*`, `vite.config.*` with test section, `jest.config.*`, `package.json` has jest config, `*.test.*` or `*.spec.*` files
- Verify: `npx vitest --version` or `npx jest --version`
- Default: vitest
- Install: `npm install -D vitest`

## Go

**Linter:**
- Check: `.golangci.yml`, `.golangci.yaml`
- Verify: `golangci-lint --version`
- Default: golangci-lint
- Install: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`

**Formatter:** gofmt (built-in, always `ready` if `go` exists)

**Test Runner:** go test (built-in, always `ready` if `go` exists)

## Rust

**Linter:** clippy (built-in, always `ready` if `cargo` exists)
- Verify: `cargo clippy --version`

**Formatter:** rustfmt (built-in, always `ready` if `cargo` exists)
- Verify: `rustfmt --version`

**Test Runner:** cargo test (built-in, always `ready`)

## Java

**Linter:**
- Check: `checkstyle.xml`, `checkstyle/`, spotbugs config, `pom.xml` has checkstyle plugin
- Verify: tool-specific
- Default: checkstyle (via build tool plugin)

**Formatter:**
- Check: google-java-format config, `.editorconfig` with java settings
- Default: google-java-format

**Test Runner:**
- Check: `src/test/` directory, junit dependencies in pom.xml/build.gradle
- Verify: `mvn test -q` or `gradle test`
- Default: maven test or gradle test (matches project build tool)

## C#

**Linter:** dotnet analyzers (built-in, always `ready` if `dotnet` exists)
**Formatter:** dotnet format (built-in, always `ready`)
- Verify: `dotnet format --version`
**Test Runner:** dotnet test (built-in, always `ready`)
- Verify: `dotnet test --list-tests 2>&1 | head -3`

## PHP

**Linter:**
- Check: `phpstan.neon`, `phpstan.neon.dist`, `phpcs.xml`, `phpcs.xml.dist`
- Verify: `vendor/bin/phpstan --version` or `vendor/bin/phpcs --version`
- Default: phpstan
- Install: `composer require --dev phpstan/phpstan`

**Formatter:**
- Check: `.php-cs-fixer.php`, `.php-cs-fixer.dist.php`
- Verify: `vendor/bin/php-cs-fixer --version`
- Default: php-cs-fixer
- Install: `composer require --dev friendsofphp/php-cs-fixer`

**Test Runner:**
- Check: `phpunit.xml`, `phpunit.xml.dist`
- Verify: `vendor/bin/phpunit --version`
- Default: phpunit
- Install: `composer require --dev phpunit/phpunit`

## Ruby

**Linter:**
- Check: `.rubocop.yml`
- Verify: `bundle exec rubocop --version` or `rubocop --version`
- Default: rubocop
- Install: `bundle add rubocop --group development`

**Formatter:** rubocop (same tool, built-in formatting)

**Type Checker:**
- Check: `sorbet/` directory, `.srb/` directory
- Verify: `bundle exec srb --version`
- Default: none (optional, skip if missing)

**Test Runner:**
- Check: `spec/` directory → rspec, `test/` directory → minitest, `.rspec` file
- Verify: `bundle exec rspec --version` or `bundle exec ruby -e "require 'minitest'"`
- Default: minitest

## Kotlin

**Linter:**
- Check: `.editorconfig` with ktlint settings, `detekt.yml`, `detekt-config.yml`
- Verify: `ktlint --version` or `detekt --version`
- Default: ktlint
- Install: via gradle plugin

**Formatter:** ktlint (same tool, built-in formatting)

**Test Runner:** gradle test (built-in if gradle exists)
- Verify: `gradle test --dry-run 2>&1 | head -3`

## Swift

**Linter:**
- Check: `.swiftlint.yml`
- Verify: `swiftlint version`
- Default: swiftlint
- Install: `brew install swiftlint`

**Formatter:**
- Check: `.swiftformat`
- Verify: `swiftformat --version`
- Default: swiftformat
- Install: `brew install swiftformat`

**Test Runner:** swift test / XCTest (built-in if `swift` exists)
- Verify: `swift test --list-tests 2>&1 | head -3`

## Dart / Flutter

**Linter:** dart analyze (built-in, always `ready` if `dart` exists)
- Config: `analysis_options.yaml`

**Formatter:** dart format (built-in, always `ready`)

**Test Runner:**
- Check: `test/` directory
- Verify: `dart test --list 2>&1 | head -3` or `flutter test --list 2>&1 | head -3`
- Default: dart test (or flutter test if flutter project)

## Elixir

**Linter:**
- Check: `.credo.exs`
- Verify: `mix credo --version`
- Default: credo
- Install: add `{:credo, "~> 1.7", only: [:dev, :test]}` to mix.exs deps

**Formatter:** mix format (built-in, always `ready` if `mix` exists)

**Type Checker:**
- Check: dialyxir in mix.exs deps
- Verify: `mix dialyzer --version`
- Default: none (optional, skip if missing)

**Test Runner:** ExUnit (built-in, always `ready`)
- Verify: `mix test --list 2>&1 | head -3`

## Scala

**Linter:**
- Check: `.scalafix.conf`, wartremover in build.sbt plugins
- Verify: `sbt "scalafix --check" 2>&1 | head -3`
- Default: scalafix
- Install: add sbt-scalafix plugin to `project/plugins.sbt`

**Formatter:**
- Check: `.scalafmt.conf`
- Verify: `scalafmt --version`
- Default: scalafmt
- Install: add sbt-scalafmt plugin to `project/plugins.sbt`

**Test Runner:**
- Check: scalatest/specs2 in build.sbt deps, `src/test/` directory
- Verify: `sbt test 2>&1 | head -5`
- Default: sbt test

## C / C++

**Linter:**
- Check: `.clang-tidy`
- Verify: `clang-tidy --version`
- Default: clang-tidy
- Install: comes with clang/LLVM toolchain

**Formatter:**
- Check: `.clang-format`
- Verify: `clang-format --version`
- Default: clang-format
- Install: comes with clang/LLVM toolchain

**Test Runner:**
- Check: CMakeLists.txt with `enable_testing()`, `gtest` / `catch2` in deps
- Verify: `ctest --test-dir build --list 2>&1 | head -3`
- Default: ctest
```

- [ ] **Step 2: Commit**

```bash
git add skills/setup/references/toolchain-matrix.md
git commit -m "feat(setup): add 14-language toolchain detection matrix

Complete detection rules for Python, TypeScript, Go, Rust, Java, C#,
PHP, Ruby, Kotlin, Swift, Dart, Elixir, Scala, and C/C++."
```

---

### Task 3: Create `references/tooling.md`

**Files:**
- Create: `skills/setup/references/tooling.md`

- [ ] **Step 1: Write the tooling reference**

Create `skills/setup/references/tooling.md`:

```markdown
# Module: Install Missing Tools

Install tools that Phase 1 marked as `missing`. Skip `ready` and
`broken` tools. After installation, update policy.json and AGENTS.md.

## Process

### 1. Iterate Missing Tools

For each tool with status `missing` from Phase 1:

1. Look up the install command in `references/toolchain-matrix.md`
2. Use the project's package manager (never global, never sudo)
3. Run the install command
4. Verify: run `<tool> --version` or equivalent
5. If install fails (permission error, network, etc.):
   - Report the error to the user
   - Do NOT use sudo
   - Skip this tool and continue with the next
   - Note it in the completion summary as ⚠

### 2. Update Policy

After all tools are installed, update `.ship/ship.policy.json`:

For each newly installed tool, add to `quality.pre_commit`:

```bash
# Example: add ruff to pre_commit
jq '.quality.pre_commit += [{"command": "ruff check .", "name": "linter"}]' \
  .ship/ship.policy.json > .ship/ship.policy.json.tmp && \
  mv .ship/ship.policy.json.tmp .ship/ship.policy.json
```

Use the actual tool command, not a hardcoded default.

### 3. Update AGENTS.md

Update the Commands table in AGENTS.md to include newly installed tools.
Use Edit to update the relevant lines.

### 4. Update .gitignore

Add install artifacts if not already present:
- Python: `__pycache__/`, `*.pyc`, `.ruff_cache/`, `.venv/`
- TypeScript: `node_modules/`, `dist/`, `coverage/`
- Go: `/bin/`, `/vendor/`
- PHP: `vendor/`
- Ruby: `.bundle/`
- General: `.DS_Store`, `*.log`

### 5. Commit

```bash
git add -A
git commit -m "feat(tooling): install <list of installed tools>"
```

## Install Commands by Package Manager

| PM | Install dev dependency |
|----|----------------------|
| npm | `npm install -D <pkg>` |
| yarn | `yarn add -D <pkg>` |
| pnpm | `pnpm add -D <pkg>` |
| pip | `pip install <pkg>` |
| uv | `uv add --dev <pkg>` |
| go | `go install <pkg>@latest` |
| cargo | included with rustup |
| composer | `composer require --dev <pkg>` |
| bundle | `bundle add <pkg> --group development` |
| brew | `brew install <pkg>` (only for Swift tools) |
| mix | add to deps in mix.exs |
| sbt | add to plugins.sbt |

## Permission Errors

If any install fails with permission denied:
- Do NOT use sudo
- Suggest the user fix permissions or use a version manager (nvm, pyenv)
- Reference `references/runtime-install-guide.md` for platform-specific guidance
```

- [ ] **Step 2: Commit**

```bash
git add skills/setup/references/tooling.md
git commit -m "feat(setup): add tooling installation reference module

Install missing tools, update policy.json pre_commit and AGENTS.md.
Never global, never sudo, closed-loop policy update."
```

---

### Task 4: Create `references/ci.md`

**Files:**
- Create: `skills/setup/references/ci.md`

- [ ] **Step 1: Write the CI reference**

Create `skills/setup/references/ci.md`:

```markdown
# Module: CI/CD Configuration

Generate GitHub Actions CI workflow, Dependabot config, and auto-labeler.
Skip any component that already exists.

## Process

### 1. Check Existing

- `.github/workflows/` has CI workflow → skip CI generation
- `.github/dependabot.yml` exists → skip Dependabot
- `.github/labeler.yml` exists → skip labeler

If all exist, skip this module entirely.

### 2. Generate CI Workflow

Read the language-specific template from `templates/`:
- TypeScript/JS: `templates/ci-node.yml`
- Python: `templates/ci-python.yml`
- Go: `templates/ci-go.yml`
- Multi-language: combine relevant jobs into one workflow
- Other languages: generate based on detected commands from Phase 1

**Replace template placeholders** with actual commands detected in
Phase 1 (or installed in the tooling module). Do not use hardcoded
commands that don't match the project's actual toolchain.

Write to `.github/workflows/ci.yml`.

### 3. Generate Dependabot

Read `templates/dependabot.yml`. Replace the package-ecosystem list
with only the ecosystems detected in Phase 1:

| Language | Ecosystem |
|----------|-----------|
| TypeScript/JS | npm |
| Python | pip |
| Go | gomod |
| Rust | cargo |
| Java (Maven) | maven |
| Java (Gradle) | gradle |
| PHP | composer |
| Ruby | bundler |

Always keep the `github-actions` ecosystem entry.

Write to `.github/dependabot.yml`.

### 4. Generate Auto-Merge Dependabot

Copy `templates/auto-merge-dependabot.yml` to
`.github/workflows/auto-merge-dependabot.yml` as-is.

### 5. Generate Labeler

Read `templates/labeler.yml` and `templates/labeler-workflow.yml`.
Adapt label rules to match actual repo directory structure detected
in Phase 1. For example, if the repo has `frontend/` and `backend/`,
create labels for those directories.

Write to `.github/labeler.yml` and `.github/workflows/labeler.yml`.

### 6. Commit

```bash
git add .github/
git commit -m "chore: set up CI/CD (GitHub Actions, Dependabot, auto-labeler)"
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/setup/references/ci.md
git commit -m "feat(setup): add CI/CD configuration reference module

GitHub Actions, Dependabot, labeler generation from templates."
```

---

### Task 5: Create `references/review.md`

**Files:**
- Create: `skills/setup/references/review.md`

- [ ] **Step 1: Write the review reference**

Create `skills/setup/references/review.md`:

```markdown
# Module: AI Code Review

Configure automated AI code review on pull requests.

## Process

### 1. Check Existing

Look for existing AI review setup:
- `.github/workflows/*review*` or `*ai*` workflow files
- `.coderabbit.yaml` or CodeRabbit config
- Any workflow that runs `claude`, `codex`, or similar

If AI review already configured → skip this module.

### 2. Ask User

AskUserQuestion:

    Re-ground: Configuring automated code review for your PRs.

    Simplify: Every pull request will be automatically reviewed by AI
    before you merge it — like a second developer checking your work.

    A) Claude review (uses Anthropic API key)
    B) Codex review (uses OpenAI API key)
    C) Both — Claude + Codex cross-review (most thorough)
    D) Skip — I'll review PRs myself

If D, skip the rest of this module.

### 3. Generate Workflow

Generate `.github/workflows/ai-review.yml`:

For Claude (option A or C):
```yaml
name: AI Code Review (Claude)
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Claude Review
        run: |
          claude -p "Review this PR diff for bugs, security issues, and best practices. Be concise." < <(git diff ${{ github.event.pull_request.base.sha }}..${{ github.sha }})
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

For Codex (option B or C):
```yaml
name: AI Code Review (Codex)
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  codex-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Codex Review
        run: codex review
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

For both (option C): combine into one workflow with two jobs.

### 4. Remind User About Secrets

Tell the user:
> Remember to add your API key as a GitHub repository secret:
> Settings → Secrets → Actions → New repository secret
> - ANTHROPIC_API_KEY (for Claude review)
> - OPENAI_API_KEY (for Codex review)

### 5. Commit

```bash
git add .github/workflows/ai-review.yml
git commit -m "chore: set up AI code review on PRs"
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/setup/references/review.md
git commit -m "feat(setup): add AI code review reference module

Claude/Codex/both PR review workflow generation."
```

---

### Task 6: Verify and Final Commit

**Files:**
- Verify: all files in `skills/setup/`

- [ ] **Step 1: Verify file structure**

```bash
find skills/setup/ -type f | sort
```

Expected output:
```
skills/setup/SKILL.md
skills/setup/references/ci.md
skills/setup/references/review.md
skills/setup/references/runtime-install-guide.md
skills/setup/references/toolchain-matrix.md
skills/setup/references/tooling.md
skills/setup/templates/agents-md.md
skills/setup/templates/auto-merge-dependabot.yml
skills/setup/templates/ci-go.yml
skills/setup/templates/ci-node.yml
skills/setup/templates/ci-python.yml
skills/setup/templates/dependabot.yml
skills/setup/templates/labeler-workflow.yml
skills/setup/templates/labeler.yml
skills/setup/templates/ship.policy.json
```

- [ ] **Step 2: Verify SKILL.md references are correct**

Check that SKILL.md references match actual file paths:
- `references/toolchain-matrix.md` → exists
- `references/tooling.md` → exists
- `references/ci.md` → exists
- `references/review.md` → exists
- `templates/ship.policy.json` → exists
- `templates/agents-md.md` → exists

```bash
grep -oE 'references/[a-z-]+\.md|templates/[a-z-]+\.(md|json|yml)' skills/setup/SKILL.md | sort -u | while read f; do
  [ -f "skills/setup/$f" ] && echo "✓ $f" || echo "✗ MISSING: $f"
done
```

Expected: all ✓

- [ ] **Step 3: Verify line count**

```bash
wc -l skills/setup/SKILL.md
```

Expected: ~120-150 lines

- [ ] **Step 4: Count total reference lines**

```bash
wc -l skills/setup/references/*.md
```

Record totals. Each reference should be self-contained.

- [ ] **Step 5: Final check — no old Phase 0 remnants**

```bash
grep -i "empty repo\|scaffold\|Phase 0\|npm init\|cargo init" skills/setup/SKILL.md
```

Expected: no matches (Phase 0 removed)
