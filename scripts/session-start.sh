#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects .ship/rules/CONVENTIONS.md into conversation context.
# If no CONVENTIONS.md exists, outputs nothing (no-op).

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONVENTIONS_FILE="$REPO_ROOT/.ship/rules/CONVENTIONS.md"

if [[ ! -f "$CONVENTIONS_FILE" ]]; then
  exit 0
fi

CONTENT=$(cat "$CONVENTIONS_FILE")
PREFIX="The following project-specific conventions MUST be followed. These are semantic rules that require your judgment — violations cause bugs, security issues, or architectural breakage."

# Use jq for proper JSON escaping, fall back to python if jq unavailable
if command -v jq &>/dev/null; then
  CONTEXT=$(printf '%s\n\n%s' "$PREFIX" "$CONTENT" | jq -Rs .)
elif command -v python3 &>/dev/null; then
  CONTEXT=$(printf '%s\n\n%s' "$PREFIX" "$CONTENT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  exit 0
fi

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${CONTEXT}
  }
}
EOF

exit 0
