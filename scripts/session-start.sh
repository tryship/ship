#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects project context into conversation:
#   1. .ship/rules/CONVENTIONS.md — semantic rules for code
#   2. docs/DESIGN_INDEX.md — design doc index for architectural guardrails
# If neither file exists, outputs nothing (no-op).

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONVENTIONS_FILE="$REPO_ROOT/.ship/rules/CONVENTIONS.md"
DESIGN_INDEX_FILE="$REPO_ROOT/docs/DESIGN_INDEX.md"

PARTS=""

# Part 1: Conventions
if [[ -f "$CONVENTIONS_FILE" ]]; then
  PARTS="The following project-specific conventions MUST be followed. These are semantic rules that require your judgment — violations cause bugs, security issues, or architectural breakage.

$(cat "$CONVENTIONS_FILE")"
fi

# Part 2: Design doc index
if [[ -f "$DESIGN_INDEX_FILE" ]]; then
  SEPARATOR=""
  [[ -n "$PARTS" ]] && SEPARATOR="

---

"
  PARTS="${PARTS}${SEPARATOR}Design doc index loaded. Before making architectural changes, check if a design doc covers the affected area. Read the relevant doc to understand boundaries and trade-offs before proceeding.

$(cat "$DESIGN_INDEX_FILE")"
fi

# Nothing to inject
if [[ -z "$PARTS" ]]; then
  exit 0
fi

# Use jq for proper JSON escaping, fall back to python if jq unavailable
if command -v jq &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | jq -Rs .)
elif command -v python3 &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  exit 0
fi

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": %s\n  }\n}\n' "$CONTEXT"

exit 0
