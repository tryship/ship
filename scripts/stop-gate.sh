#!/bin/bash
set -u
# Ship quality gate — prevents the orchestrator from exiting until all
# pipeline phases are complete. Pure artifact-driven: artifact exists =
# phase ran, missing artifact = phase skipped.
#
# CONDITIONAL: Only active when .claude/ship-coding.local.md exists.
# Non-ship-coding sessions and subagents are never blocked.
#
# Returns {"decision":"block","reason":"..."} to prevent stop, or exit 0 to allow.

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Prevent infinite loop — if we already blocked once, let it go
[ "$STOP_ACTIVE" = "true" ] && exit 0
[ -z "$CWD" ] && exit 0

# ── SUBAGENT BYPASS ───────────────────────────────────────────
# Subagents have agent_id in hook input; orchestrator does not.
# Only the orchestrator should be blocked by the quality gate.
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
[ -n "$AGENT_ID" ] && exit 0

# ── STATE FILE CHECK ──────────────────────────────────────────
# No active ship-coding session → allow exit
STATE_FILE="$CWD/.claude/ship-coding.local.md"
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Session isolation: only enforce for the session that started ship-coding
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
STATE_SESSION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
  | grep '^session_id:' | sed 's/session_id: *//' | tr -d '"')
if [ -n "$STATE_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# ── FIND TASK DIR ─────────────────────────────────────────────
REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")

# Read task_dir from state file if available
TASK_DIR=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
  | grep '^task_dir:' | sed 's/task_dir: *//' | tr -d '"')

# Fallback: scan .ship/tasks/
if [ -z "$TASK_DIR" ] || [ ! -d "$REPO_ROOT/$TASK_DIR" ]; then
  TASK_DIR_ABS=$(find "$REPO_ROOT/.ship/tasks" -type d -name "plan" -maxdepth 2 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
  [ -z "$TASK_DIR_ABS" ] && exit 0
  TASK_DIR="$TASK_DIR_ABS"
else
  TASK_DIR="$REPO_ROOT/$TASK_DIR"
fi

# ── WORKFLOW CONFIG ──────────────────────────────────────────
# All phases required by default. QA and simplify are optional
# because they depend on whether code changes were made.
PLAN_REQUIRED="required"
REVIEW_REQUIRED="required"
VERIFY_REQUIRED="required"
QA_REQUIRED="optional"
SIMPLIFY_REQUIRED="optional"

PROBLEMS=""

# ── 1. DESIGN ARTIFACTS (Step 2) ──────────────────────────────
if [ "$PLAN_REQUIRED" = "required" ]; then
  if [ ! -s "$TASK_DIR/plan/spec.md" ]; then
    PROBLEMS="${PROBLEMS}\n- plan/spec.md is missing. Go back to Step 2 (Design) — dispatch plan subagent to produce the spec."
  fi
  if [ ! -s "$TASK_DIR/plan/plan.md" ]; then
    PROBLEMS="${PROBLEMS}\n- plan/plan.md is missing. Go back to Step 2 (Design) — dispatch plan subagent to produce the implementation plan."
  fi
fi

# ── 2. REVIEW ARTIFACT (Step 5) ──────────────────────────────
if [ "$REVIEW_REQUIRED" = "required" ]; then
  if [ ! -s "$TASK_DIR/review.md" ]; then
    PROBLEMS="${PROBLEMS}\n- review.md is missing. Go back to Step 5 (Review) — dispatch code review subagent to review the diff against the spec."
  fi
fi

# ── 3. VERIFY ARTIFACT (Step 6) ──────────────────────────────
if [ "$VERIFY_REQUIRED" = "required" ]; then
  if [ ! -s "$TASK_DIR/verify.md" ]; then
    PROBLEMS="${PROBLEMS}\n- verify.md is missing. Go back to Step 6 (Verify) — dispatch verification subagent to run tests, lint, and spec compliance."
  elif grep -qi 'spec compliance:.*FAIL\|Coverage verdict:.*FAIL' "$TASK_DIR/verify.md" 2>/dev/null; then
    PROBLEMS="${PROBLEMS}\n- verify.md contains FAIL verdicts. Go back to Step 6 (Verify) — fix the failing checks and re-run verification."
  fi
fi

# ── 4. PROOF EVIDENCE (Step 6) ────────────────────────────────
CURRENT_HEAD=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
PROOF_DIR="$TASK_DIR/proof/current"

if [ -d "$PROOF_DIR" ]; then
  for txt in "$PROOF_DIR"/*.txt; do
    [ ! -e "$txt" ] && continue
    FILE_SHA=$(head -1 "$txt" 2>/dev/null | sed -n 's/^HEAD_SHA=//p')
    if [ -n "$FILE_SHA" ] && [ "$FILE_SHA" != "$CURRENT_HEAD" ]; then
      echo "[Ship] WARNING: $(basename "$txt") evidence is stale (collected at $FILE_SHA, HEAD is $CURRENT_HEAD). Re-run Step 6 (Verify) to refresh." >&2
    fi
  done
fi

# ── 5. CODE CHANGE DETECTION ─────────────────────────────────
HAS_CODE_CHANGES="false"
if [ -d "$REPO_ROOT/.git" ]; then
  CODE_FILES=$(git -C "$REPO_ROOT" diff main...HEAD --name-only 2>/dev/null \
    | grep -v -E '(_test\.go|test_.*\.py|\.test\.(ts|tsx|js)|\.md$|\.yaml$|\.yml$|\.json$|\.toml$|\.lock$)' \
    | grep -E '\.(go|py|ts|tsx|js|jsx|sh)$' \
    | head -1)
  [ -n "$CODE_FILES" ] && HAS_CODE_CHANGES="true"
fi

# ── 6. QA ARTIFACT (Step 7) ──────────────────────────────────
if [ "$QA_REQUIRED" = "required" ] && [ "$HAS_CODE_CHANGES" = "true" ]; then
  # Check both old path (qa.md) and new path (qa/qa.md)
  QA_FILE=""
  [ -s "$TASK_DIR/qa/qa.md" ] && QA_FILE="$TASK_DIR/qa/qa.md"
  [ -z "$QA_FILE" ] && [ -s "$TASK_DIR/qa.md" ] && QA_FILE="$TASK_DIR/qa.md"
  if [ -z "$QA_FILE" ]; then
    PROBLEMS="${PROBLEMS}\n- qa.md is missing but code was changed. Go back to Step 7 (QA Evaluation) — dispatch qa subagent. You MUST NOT skip QA yourself; only qa can return a SKIP verdict."
  else
    if ! grep -qE '<!-- QA_RESULT: (PASS|FAIL|SKIP) [0-9]+/10' "$QA_FILE" 2>/dev/null; then
      PROBLEMS="${PROBLEMS}\n- qa.md has malformed or missing QA_RESULT header. Go back to Step 7 (QA Evaluation) — re-dispatch qa subagent to produce a valid evaluation."
    elif grep -q '<!-- QA_RESULT: FAIL' "$QA_FILE" 2>/dev/null; then
      PROBLEMS="${PROBLEMS}\n- qa.md has FAIL result. Go back to Step 4 (Implement) — fix the failing criteria, then re-run Steps 5-7 (Review → Verify → QA)."
    fi
    # Taint check
    TAINT=$(grep -cE '\.ship/tasks/[^/]+/(review\.md|verify\.md|plan/plan\.md)' "$QA_FILE" 2>/dev/null || echo 0)
    if [ "$TAINT" -gt 0 ]; then
      echo "[Ship] WARNING: qa.md references generator artifact paths ($TAINT matches) — evaluation may be tainted. Consider re-running Step 7 (QA Evaluation) with a clean subagent." >&2
    fi
  fi
fi

# ── 7. SIMPLIFY ARTIFACT (Step 8) ────────────────────────────
if [ "$SIMPLIFY_REQUIRED" = "required" ] && [ "$HAS_CODE_CHANGES" = "true" ]; then
  if [ ! -s "$TASK_DIR/simplify.md" ]; then
    PROBLEMS="${PROBLEMS}\n- simplify.md is missing but code was changed. Go back to Step 8 (Simplify) — dispatch simplify subagent for behavior-preserving cleanup."
  fi
fi

# ── 8. EMPTY ARTIFACTS ───────────────────────────────────────
for f in "$TASK_DIR"/*.md; do
  [ ! -e "$f" ] && continue
  BASENAME=$(basename "$f")
  if [ ! -s "$f" ]; then
    case "$BASENAME" in
      review.md)   PROBLEMS="${PROBLEMS}\n- $BASENAME exists but is empty. Go back to Step 5 (Review) — the review subagent started but did not finish." ;;
      verify.md)   PROBLEMS="${PROBLEMS}\n- $BASENAME exists but is empty. Go back to Step 6 (Verify) — the verify subagent started but did not finish." ;;
      qa.md)       PROBLEMS="${PROBLEMS}\n- $BASENAME exists but is empty. Go back to Step 7 (QA Evaluation) — the QA subagent started but did not finish." ;;
      simplify.md) PROBLEMS="${PROBLEMS}\n- $BASENAME exists but is empty. Go back to Step 8 (Simplify) — the simplify subagent started but did not finish." ;;
      *)           PROBLEMS="${PROBLEMS}\n- $BASENAME exists but is empty." ;;
    esac
  fi
done

# ── 9. GIT EVIDENCE ──────────────────────────────────────────
if [ -d "$REPO_ROOT/.git" ]; then
  COMMIT_COUNT=$(git -C "$REPO_ROOT" rev-list --count main..HEAD 2>/dev/null || echo 0)
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    PROBLEMS="${PROBLEMS}\n- No commits between main and HEAD. Go back to Step 4 (Implement) — no code was committed. Dispatch implementation subagents to write and commit code."
  fi
fi

# ── VERDICT ───────────────────────────────────────────────────
if [ -n "$PROBLEMS" ]; then
  REASON=$(printf "Ship quality gate BLOCKED. You cannot exit until all pipeline phases are complete.%b\n\nPipeline: Bootstrap → Design → Approve → Implement → Review → Verify → QA → Simplify → Handoff.\nResume from the earliest incomplete step listed above." "$PROBLEMS")
  jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
else
  # All artifacts present and valid — clean up and allow exit
  rm -f "$STATE_FILE"

  # Clean up session-scoped git hooks
  if [ -d "$REPO_ROOT/.git/hooks" ]; then
    for HOOK in pre-commit commit-msg; do
      HOOK_FILE="$REPO_ROOT/.git/hooks/$HOOK"
      if [ -f "$HOOK_FILE" ] && grep -q "# ship-session-hook" "$HOOK_FILE" 2>/dev/null; then
        rm -f "$HOOK_FILE"
      fi
    done
  fi

  exit 0
fi
