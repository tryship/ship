#!/bin/bash
set -u
# Ship auto stop gate — prevents the orchestrator from exiting while
# a /ship:auto pipeline is active.
#
# Logic:
#   1. No state file → allow exit
#   2. Different session → allow exit
#   3. Subagent → allow exit
#   4. State file exists, same session → block exit, tell agent which phase to resume
#
# State file: .ship/ship-auto.local.md (YAML frontmatter + description body)
# Returns {"decision":"block","reason":"..."} to prevent stop, or exit 0 to allow.

INPUT=$(cat)

# ── SUBAGENT BYPASS ──────────────────────────────────────────
# Subagents should never be blocked by the stop gate.
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
[ -n "$AGENT_ID" ] && exit 0

# ── STATE FILE CHECK ─────────────────────────────────────────
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[ -z "$CWD" ] && exit 0

STATE_FILE="$CWD/.ship/ship-auto.local.md"
[ ! -f "$STATE_FILE" ] && exit 0

# ── PARSE FRONTMATTER ────────────────────────────────────────
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")

PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//')
TASK_ID=$(echo "$FRONTMATTER" | grep '^task_id:' | sed 's/task_id: *//')
BRANCH=$(echo "$FRONTMATTER" | grep '^branch:' | sed 's/branch: *//')
BASE_BRANCH=$(echo "$FRONTMATTER" | grep '^base_branch:' | sed 's/base_branch: *//')

# ── SESSION ISOLATION ────────────────────────────────────────
# Only block the session that started the pipeline.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' | tr -d '"')
if [ -n "$STATE_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# ── VALIDATE STATE ───────────────────────────────────────────
if [ -z "$PHASE" ] || [ -z "$TASK_ID" ]; then
  echo "⚠️  Ship auto: State file corrupted (missing phase or task_id). Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── READ DESCRIPTION ─────────────────────────────────────────
DESCRIPTION=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

# ── BLOCK EXIT ───────────────────────────────────────────────
REASON="[Ship] Auto pipeline is active. Do not exit.
Task: $TASK_ID
Branch: $BRANCH
Base branch: $BASE_BRANCH
Current phase: $PHASE
Description: $DESCRIPTION

Resume the pipeline from phase: $PHASE"

jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
