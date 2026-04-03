# Module: AI Code Review

Purpose: Configure automated AI code review on pull requests.

## Process

### 1. Check Existing

- Look for existing workflow files matching `.github/workflows/*review*` or `.github/workflows/*ai*`.
- Look for `.coderabbit.yaml`.
- Look for any workflow already running `claude` or `codex`.
- If any of those already exist, skip this module to avoid duplicate review automation.

### 2. Ask User

- Ask exactly one `AskUserQuestion`.
- Use a Re-ground/Simplify format:
  - Re-ground: explain that this module adds automated AI review on pull requests and requires repository secrets.
  - Simplify: offer one clear choice among four options.
- Options:
  - `A) Claude review` — uses an Anthropic API key
  - `B) Codex review` — uses an OpenAI API key
  - `C) Both Claude + Codex` — most thorough
  - `D) Skip`
- If the user chooses `D`, skip the rest of this module.

Suggested prompt structure:

```text
Re-ground: This module can add automated AI review on pull requests. It will create a GitHub Actions workflow and requires one or more API keys stored as repository secrets.

Simplify: Which review setup do you want?
A) Claude review
B) Codex review
C) Both Claude + Codex (most thorough)
D) Skip
```

### 3. Generate Workflow

- Write the workflow to `.github/workflows/ai-review.yml`.
- If the user chose Claude only, generate the Claude job.
- If the user chose Codex only, generate the Codex job.
- If the user chose both, generate one workflow with two jobs.

Claude workflow example:

```yaml
name: AI Review
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Review PR with Claude
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          git fetch origin "${{ github.base_ref }}"
          git diff "origin/${{ github.base_ref }}...HEAD" > pr.diff
          claude -p --permission-mode bypassPermissions "Review this pull request diff for bugs, regressions, security issues, and missing tests. Respond with actionable review comments only." < pr.diff
```

Codex workflow example:

```yaml
name: AI Review
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  codex-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Review PR with Codex
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          git fetch origin "${{ github.base_ref }}"
          codex review --base "origin/${{ github.base_ref }}" --head HEAD
```

For both providers, combine them into one workflow with two jobs: `claude-review` and `codex-review`.

### 4. Remind User About Secrets

- Tell the user to add the required API key as a GitHub repository secret.
- Path: `Settings -> Secrets -> Actions -> New repository secret`.
- Claude requires `ANTHROPIC_API_KEY`.
- Codex requires `OPENAI_API_KEY`.

### 5. Commit

- Commit with a conventional commit message:

```text
chore: set up AI code review on PRs
```
