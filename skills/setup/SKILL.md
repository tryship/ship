---
name: setup
version: 1.0.0
description: Bootstrap a repo for AI-ready development with Ship enforcement. Detects languages and tooling across 14 languages, generates security policy (ship.policy.json) and AI handbook (AGENTS.md). Optional modules install missing tools, configure CI/CD, and set up AI code review. Use when setup, init, bootstrap, make repo AI-ready.
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

One command, repo goes from bare to AI-ready with Ship enforcement active. Idempotent.

## Preamble

`Bash("${CLAUDE_PLUGIN_ROOT}/bin/preamble.sh setup")`

## Phase 1: Detect (automatic)

No user interaction in this phase. Detect first, never assume, and respect existing config.

### 1.1 Pre-flight

- Check `git` is available. If missing, stop and tell the user Ship setup requires git first.
- Check whether the cwd is already a git repo with `git rev-parse --is-inside-work-tree`.
- If not a repo, run `git init` before continuing.
- Record whether the repo was newly initialized so later steps can explain what changed.

### 1.2 Language + Package Manager

Scan repo files first, then verify the relevant package manager or build tool exists on PATH.

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

### 1.3 Toolchain Detection

- For each detected language, scan all mainstream tools by category: linter, formatter, type checker, test runner.
- Use config files, lockfiles, package manifests, scripts, and executable checks to determine what is already in use.
- Built-in tools are always `ready` when the runtime exists, for example `gofmt`, `go test`, `cargo fmt`, `cargo test`, `swift test`.
- Status per tool must be one of `ready`, `missing`, or `broken`.
- `ready`: executable and config are usable as-is.
- `missing`: repo has no configured tool for that category.
- `broken`: config references a tool that is unavailable or clearly misconfigured.
- Never invent a default stack when a repo already picked one.
- Reference [references/toolchain-matrix.md](references/toolchain-matrix.md) for the full detection matrix.

### 1.4 Existing Configuration

Check and store in working memory:

- `.ship/ship.policy.json`
- `AGENTS.md` and `CLAUDE.md`
- `.gitignore`
- `.github/workflows/*.yml`
- `.github/dependabot.yml`

## Phase 2: Choose (1 user decision)

Ask exactly one `AskUserQuestion` after detection. The prompt must show:

- Detection results by language and tool, including `ready` / `missing` / `broken`
- Which Ship policy gates will not work because required tools are missing or broken
- Three tiers:

| Tier | Selection |
|---|---|
| A | `Full setup (recommended)` — install missing tools, configure CI, generate policy + `AGENTS.md`. Outcome: repo ends with enforcement, checks, and automation wired in. |
| B | `Basic setup` — generate policy + `AGENTS.md` only. Outcome: Ship uses the repo’s current toolchain without installing anything new. |
| C | `Custom` — choose modules with checkboxes: `1.[x] Security policy`, `2.[x] AI handbook`, `3.[ ] Install missing tools`, `4.[ ] CI/CD`, `5.[ ] AI Code Review`. Include custom boundaries input defaulting to `.env*, *.pem, *.key, credentials*, secrets/`. |

At the bottom, include:

- `Any special notes AI should know about this project? (optional, Enter to skip)`

## Phase 3: Modules (per tier) — run BEFORE policy generation

**Why modules run first:** `ship.policy.json` activates enforcement hooks
the moment it exists. If CI/CD files or tooling configs are written after
the policy, the policy's own `read_only` rules (e.g. `.github/workflows/**`)
will block setup from completing. Therefore: write all files first, generate
the policy last.

Tier A runs all modules. Tier B skips all modules. Tier C runs only checked modules.

**Hard rule:** Execute ONLY the modules the user selected. Never run a
module the user did not check. This is not a suggestion — it is a gate.

| Module | Action |
|---|---|
| Install Tools | Read [references/tooling.md](references/tooling.md) |
| CI/CD | Read [references/ci.md](references/ci.md) |
| AI Code Review | Read [references/review.md](references/review.md) |

After each module, commit atomically:
```
git add <changed files>
git commit -m "<conventional commit message>"
```

## Phase 4: Core — generate policy and AGENTS.md last

Always run this phase for every tier. This is the final phase because
`ship.policy.json` activates enforcement hooks immediately on creation.

### 4.1 Generate `AGENTS.md`

- Read [templates/agents-md.md](templates/agents-md.md).
- Fill commands with the actual detected (and newly installed) build, test, lint, format, and typecheck commands.
- Fill repo map, code style, boundaries, testing notes, and gotchas from actual repo inspection.
- Keep the generated file under 200 lines.
- If `AGENTS.md` or `CLAUDE.md` already exists, show a diff and ask before replacing.
- Show the generated `AGENTS.md` to the user for review before committing.

### 4.2 Auxiliary

- Create `.ship/audit/`.
- Update `.gitignore` to include `.ship/tasks/` and `.ship/audit/`, not `.ship/` broadly.
- Add language-specific ignores (`node_modules/`, `__pycache__/`, `.venv/`, `dist/`, etc.) if not already present.

### 4.3 Generate `.ship/ship.policy.json` — LAST

- Read [templates/ship.policy.json](templates/ship.policy.json).
- Fill `quality.pre_commit` with only `ready` tools (including newly installed ones).
  **Each entry MUST be an object** with `command` and `name` keys:
  ```json
  {"command": "uv run ruff check .", "name": "linter"}
  ```
  Do NOT use plain strings. The enforcement hook reads `.command` and `.name` from each entry.
- Fill `quality.require_tests` patterns from detected source and test layout.
- Merge boundaries from the chosen tier and custom boundaries input.
- If a policy already exists, show a diff and ask for confirmation before overwriting.
- Use `jq` for all JSON manipulation.

### 4.4 Commit

Commit all core files atomically:
```
git add AGENTS.md .ship/ .gitignore
git commit -m "feat: generate ship policy and AGENTS.md"
```

## Done

End with an outcome-oriented summary:

- `Security`: policy generated, boundaries active, audit path ready
- `Quality`: detected checks enforced, plus warnings for anything still missing or broken
- `CI/CD`: include only if configured
- `Documentation`: `AGENTS.md` generated or updated
- Warn clearly about incomplete items so the user knows what still needs manual work
- Next step: `/ship:auto`

## What Setup Does NOT Do

- Scaffold empty repos beyond `git init`
- Configure deployment or hosting
- Modify source code outside setup artifacts
- Replace existing tool configs just because Ship prefers a different stack
- Install global packages or use `sudo`
