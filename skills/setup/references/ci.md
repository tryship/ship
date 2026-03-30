# Module: CI/CD Configuration

Purpose: Generate GitHub Actions CI workflow, Dependabot config, and auto-labeler. Skip any component that already exists.

## Process

### 1. Check Existing

- Check whether `.github/workflows/` already contains a CI workflow.
- If `.github/dependabot.yml` already exists, skip Dependabot generation.
- If `.github/labeler.yml` already exists, skip labeler generation.
- If `.github/workflows/auto-merge-dependabot.yml` already exists, skip auto-merge generation.
- If all CI/CD components already exist, skip the entire module.

### 2. Generate CI Workflow

- Read the language-specific templates from `templates/`:
  - `ci-node.yml`
  - `ci-python.yml`
  - `ci-go.yml`
- If the repo is multi-language, combine jobs into one `.github/workflows/ci.yml`.
- For other languages without a template, generate a workflow job from the Phase 1 detected commands.
- Replace placeholders with the actual detected commands for install, lint, format, typecheck, and test steps.
- Write the result to `.github/workflows/ci.yml`.

### 3. Generate Dependabot

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

### 4. Generate Auto-Merge Dependabot

- Copy `templates/auto-merge-dependabot.yml` to `.github/workflows/auto-merge-dependabot.yml` as-is.
- Do not customize this template in setup.

### 5. Generate Labeler

- Read `templates/labeler.yml` and `templates/labeler-workflow.yml`.
- Adapt label rules to the actual repo directory structure instead of assuming `frontend/` or `src/`.
- Keep only labels that map cleanly to real paths in the repo.
- Write:
  - `.github/labeler.yml`
  - `.github/workflows/labeler.yml`

### 6. Commit

- Commit with a conventional commit message:

```text
chore: set up CI/CD (GitHub Actions, Dependabot, auto-labeler)
```
