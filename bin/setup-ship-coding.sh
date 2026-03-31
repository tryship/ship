#!/bin/bash
# Ship Coding Setup Script
# Creates state file, bootstraps repo detection, installs session git hooks.
# Called by preamble.sh at the start of a ship-coding session.
#
# Usage: setup-ship-coding.sh <task_description> [cwd]
#
# The state file (.claude/ship-coding.local.md) is the activation signal:
# - guard-orchestrator.sh checks it → blocks Write/Edit when present
# - stop-gate.sh checks it → blocks exit until artifacts are complete
# - post-compact.sh checks it → re-injects task state after compaction
# - All hooks are no-ops when the file is absent (non-ship sessions unaffected)

set -u

TASK_DESCRIPTION="${1:-}"
CWD="${2:-$PWD}"

if [ -z "$TASK_DESCRIPTION" ]; then
  echo "❌ Error: No task description provided" >&2
  echo "   Usage: setup-ship-coding.sh <task_description> [cwd]" >&2
  exit 1
fi

# ── 1. GENERATE TASK ID + DIRECTORIES ─────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TASK_ID=$(bash "$SCRIPT_DIR/task-id.sh" "$TASK_DESCRIPTION")
mkdir -p ".ship/tasks/$TASK_ID/plan"

# ── 2. CREATE STATE FILE ──────────────────────────────────────
mkdir -p .claude
cat > .claude/ship-coding.local.md <<EOF
---
active: true
session_id: ${CLAUDE_CODE_SESSION_ID:-}
task_id: $TASK_ID
task_dir: .ship/tasks/$TASK_ID
required_artifacts:
  - plan/spec.md
  - plan/plan.md
  - review.md
  - verify.md
  - qa.md
  - simplify.md
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$TASK_DESCRIPTION
EOF

# ── 3. ENSURE .ship/ IS GITIGNORED ────────────────────────────
if [ -d "$CWD/.git" ]; then
  GITIGNORE="$CWD/.gitignore"
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF ".ship/" "$GITIGNORE" 2>/dev/null; then
    echo ".ship/" >> "$GITIGNORE"
  fi
fi

# ── 4. DETECT LANGUAGES ───────────────────────────────────────
LANGS=""
find "$CWD" -maxdepth 3 -name "go.mod" -print -quit 2>/dev/null | grep -q . && LANGS="$LANGS go" || true
find "$CWD" -maxdepth 3 \( -name "pyproject.toml" -o -name "setup.py" \) -print -quit 2>/dev/null | grep -q . && LANGS="$LANGS python" || true
find "$CWD" -maxdepth 3 -name "package.json" -print -quit 2>/dev/null | grep -q . && LANGS="$LANGS typescript" || true
find "$CWD" -maxdepth 3 -name "Cargo.toml" -print -quit 2>/dev/null | grep -q . && LANGS="$LANGS rust" || true

# ── 5. DETECT LINT CONFIG ─────────────────────────────────────
HAS_LINT="false"
{ [ -f "$CWD/.pre-commit-config.yaml" ] || \
  [ -f "$CWD/.eslintrc.js" ] || [ -f "$CWD/.eslintrc.json" ] || \
  [ -f "$CWD/eslint.config.js" ] || [ -f "$CWD/eslint.config.mjs" ] || \
  [ -f "$CWD/ruff.toml" ] || [ -f "$CWD/pyproject.toml" ] || \
  [ -f "$CWD/.golangci.yml" ] || [ -f "$CWD/.golangci.yaml" ]; } && HAS_LINT="true" || true

# ── 6. INSTALL SESSION-SCOPED GIT HOOKS ───────────────────────
HOOKS_INSTALLED=""
if [ -d "$CWD/.git" ]; then
  HOOK_DIR="$CWD/.git/hooks"
  mkdir -p "$HOOK_DIR"

  PRECOMMIT="$HOOK_DIR/pre-commit"
  if [ -f "$CWD/.pre-commit-config.yaml" ]; then
    HOOKS_INSTALLED="${HOOKS_INSTALLED} pre-commit(repo-native)"
  elif [ ! -f "$PRECOMMIT" ] || grep -q "# ship-session-hook" "$PRECOMMIT" 2>/dev/null; then
    cat > "$PRECOMMIT" << 'PCHOOK'
#!/bin/bash
# ship-session-hook — session-scoped lint, removed on session end
STAGED=$(git diff --cached --name-only --diff-filter=ACM)
[ -z "$STAGED" ] && exit 0

PY_FILES=$(echo "$STAGED" | grep '\.py$')
if [ -n "$PY_FILES" ]; then
  if command -v ruff &>/dev/null; then
    echo "$PY_FILES" | xargs ruff check --fix 2>/dev/null
    echo "$PY_FILES" | xargs ruff format 2>/dev/null
    echo "$PY_FILES" | xargs git add
  fi
fi

TS_FILES=$(echo "$STAGED" | grep -E '\.(ts|tsx|js|jsx)$')
if [ -n "$TS_FILES" ]; then
  if command -v npx &>/dev/null; then
    npx --no-install eslint --fix $TS_FILES 2>/dev/null || true
    npx --no-install prettier --write $TS_FILES 2>/dev/null || true
    echo "$TS_FILES" | xargs git add
  fi
fi

GO_FILES=$(echo "$STAGED" | grep '\.go$')
if [ -n "$GO_FILES" ]; then
  if command -v gofmt &>/dev/null; then
    gofmt -w $GO_FILES 2>/dev/null
    echo "$GO_FILES" | xargs git add
  fi
fi

exit 0
PCHOOK
    chmod +x "$PRECOMMIT"
    HOOKS_INSTALLED="${HOOKS_INSTALLED} pre-commit(injected)"
  fi
fi

# ── 7. REPORT ACTIVE TASK IF RESUMING ─────────────────────────
RESUMING=""
EXISTING_TASK_DIR="$CWD/.ship/tasks/$TASK_ID"
if [ -s "$EXISTING_TASK_DIR/plan/spec.md" ] && [ -s "$EXISTING_TASK_DIR/plan/plan.md" ]; then
  PHASE="implementing"
  [ -s "$EXISTING_TASK_DIR/review.md" ] && PHASE="verifying"
  [ -s "$EXISTING_TASK_DIR/verify.md" ] && PHASE="qa"
  [ -s "$EXISTING_TASK_DIR/qa.md" ] && PHASE="simplify"
  [ -s "$EXISTING_TASK_DIR/qa.md" ] && [ -s "$EXISTING_TASK_DIR/simplify.md" ] && PHASE="handoff"
  RESUMING="Resuming at phase: $PHASE"
fi

# ── OUTPUT ─────────────────────────────────────────────────────
echo "TASK_ID=$TASK_ID"
echo "TASK_DIR=.ship/tasks/$TASK_ID"
echo "LANGUAGES=${LANGS:- none}"
echo "HAS_LINT=$HAS_LINT"
echo "GIT_HOOKS=${HOOKS_INSTALLED:- none}"
[ -n "$RESUMING" ] && echo "$RESUMING" || true
