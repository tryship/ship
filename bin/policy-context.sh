#!/bin/bash
# Ship policy context — SessionStart hook handler.
# Reads the project's ship policy and outputs a human-readable summary
# so the session is aware of active constraints from the start.
#
# Returns: {"additionalContext": "[Ship Policy] Active rules: ..."}

set -u

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[ -z "$CWD" ] && exit 0

# ── POLICY FILE CHECK ────────────────────────────────────────
if [ ! -f "$CWD/.ship/ship.policy.json" ]; then
  exit 0
fi

# ── LOAD POLICY ──────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/lib/policy.sh"

load_policy

# ── MERGE BASE POLICY (if present) ──────────────────────────
if [ -n "${BASE_POLICY_FILE:-}" ] && [ -f "$BASE_POLICY_FILE" ]; then
  POLICY=$(merge_policies)
fi

# ── GITIGNORE MIGRATION ─────────────────────────────────────
# Old setup ignored all of .ship/; new setup only ignores .ship/tasks/ and
# .ship/audit/ so that .ship/ship.policy.json stays tracked in git.
REPO_ROOT=$(_policy_repo_root)
GITIGNORE="$REPO_ROOT/.gitignore"

if [ -f "$GITIGNORE" ]; then
  if grep -qxF '.ship/' "$GITIGNORE"; then
    # Remove the old broad ignore line
    TMPFILE=$(mktemp)
    grep -vxF '.ship/' "$GITIGNORE" > "$TMPFILE"

    # Append the narrower ignores if they are not already present
    grep -qxF '.ship/tasks/' "$TMPFILE" || printf '%s\n' '.ship/tasks/' >> "$TMPFILE"
    grep -qxF '.ship/audit/' "$TMPFILE" || printf '%s\n' '.ship/audit/' >> "$TMPFILE"

    mv "$TMPFILE" "$GITIGNORE"
  fi
fi

# ── BUILD SUMMARY ────────────────────────────────────────────
READ_ONLY_COUNT=$(echo "$POLICY" | jq '.boundaries.read_only // [] | length')
NO_ACCESS_COUNT=$(echo "$POLICY" | jq '.boundaries.no_access // [] | length')
BLOCKED_CMD_COUNT=$(echo "$POLICY" | jq '.operations.blocked_commands // [] | length')
SECRETS_ENABLED=$(echo "$POLICY" | jq -r '.secrets.enabled // false')
PRE_COMMIT_COUNT=$(echo "$POLICY" | jq '.quality.pre_commit // [] | length')

PARTS=""

if [ "$READ_ONLY_COUNT" -gt 0 ] || [ "$NO_ACCESS_COUNT" -gt 0 ]; then
  PARTS="${PARTS}${READ_ONLY_COUNT} read-only pattern(s), ${NO_ACCESS_COUNT} no-access pattern(s)"
fi

if [ "$BLOCKED_CMD_COUNT" -gt 0 ]; then
  [ -n "$PARTS" ] && PARTS="${PARTS}; "
  PARTS="${PARTS}${BLOCKED_CMD_COUNT} blocked command(s)"
fi

if [ "$SECRETS_ENABLED" = "true" ]; then
  [ -n "$PARTS" ] && PARTS="${PARTS}; "
  PARTS="${PARTS}secrets scanning enabled"
fi

if [ "$PRE_COMMIT_COUNT" -gt 0 ]; then
  [ -n "$PARTS" ] && PARTS="${PARTS}; "
  PARTS="${PARTS}${PRE_COMMIT_COUNT} pre-commit check(s)"
fi

if [ -z "$PARTS" ]; then
  PARTS="policy loaded (no specific constraints)"
fi

SUMMARY="[Ship Policy] Active rules: ${PARTS}."

jq -n --arg ctx "$SUMMARY" '{"additionalContext": $ctx}'
