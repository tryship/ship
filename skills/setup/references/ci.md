# Module: CI/CD Configuration

Purpose: Generate GitHub Actions CI workflow. Dependabot is a separate
module — only generate it if the user selected module 4.

## Process

### 1. Check Existing

- Check whether `.github/workflows/` already contains a CI workflow (check both `*.yml` and `*.yaml`).
- If a CI workflow already exists, skip CI workflow generation.

### 2. Generate CI Workflow

Generate `.github/workflows/ci.yml` dynamically from Phase 1 detection results:

- For each detected language, create a job with steps for: install deps, lint, format check, typecheck (if applicable), and test.
- Use the actual commands detected in Phase 1 (or installed in the tooling module). Do not hardcode commands.
- Use the standard `actions/setup-*` actions for each language runtime (e.g., `actions/setup-node@v4`, `actions/setup-python@v5`, `actions/setup-go@v5`).
- If the repo is multi-language, combine jobs into one workflow file.
- Reference `references/toolchain-matrix.md` for each language's linter, formatter, type checker, and test runner commands.

### 3. Commit

- Commit with a conventional commit message:

```text
chore: set up CI workflow (GitHub Actions)
```

---

# Module: Dependabot

Purpose: Generate Dependabot config and auto-merge workflow. This is a
separate module from CI/CD — only run if the user selected module 4.

### 1. Check Existing

- If `.github/dependabot.yml` already exists, skip Dependabot generation.
- If `.github/workflows/auto-merge-dependabot.yml` already exists, skip auto-merge generation.

### 2. Generate Dependabot

- Read `templates/dependabot.yml`.
- Replace the ecosystem list with the detected package ecosystems:
  - `npm`
  - `pip`
  - `gomod`
  - `cargo`
  - `maven`
  - `gradle`
  - `composer`
  - `bundler`
- Always keep `github-actions` even if no language ecosystem is detected.
- Write the result to `.github/dependabot.yml`.

### 3. Generate Auto-Merge Dependabot

- Copy `templates/auto-merge-dependabot.yml` to `.github/workflows/auto-merge-dependabot.yml` as-is.
- Do not customize this template in setup.

### 4. Commit

- Commit with a conventional commit message:

```text
chore: set up Dependabot
```
