#!/usr/bin/env bash
# Ship convention checker — PreToolUse command hook.
# Reads hook JSON from stdin, sends code + CONVENTIONS.md to claude CLI
# (Haiku, print mode) for semantic review. Blocks on violation.
#
# Requires: jq, claude CLI
# Returns: exit 0 (pass) or exit 2 + stderr message (block)
set -uo pipefail

HOOK_INPUT=$(cat)

# Find CONVENTIONS.md
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONVENTIONS_FILE="$REPO_ROOT/.ship/rules/CONVENTIONS.md"
if [[ ! -f "$CONVENTIONS_FILE" ]]; then
  exit 0
fi

# Extract file path from hook input
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Make path relative for scope matching
REL_PATH="${FILE_PATH#$REPO_ROOT/}"

# Extract scopes from CONVENTIONS.md (lines starting with "Scope:")
SCOPES=$(grep '^Scope:' "$CONVENTIONS_FILE" | sed 's/^Scope: *//' || true)
if [[ -z "$SCOPES" ]]; then
  exit 0
fi

# Check if file matches any convention scope
MATCHED=false
while IFS= read -r scope; do
  # Convert glob to regex: **/ → (.*/)?  * → [^/]*  . → \.
  PATTERN=$(echo "$scope" \
    | sed 's/\./\\./g' \
    | sed 's#\*\*/\*#.*#g' \
    | sed 's#\*\*/#(.*/)?#g' \
    | sed 's#\*#[^/]*#g')
  if echo "$REL_PATH" | grep -qE "^$PATTERN$"; then
    MATCHED=true
    break
  fi
done <<< "$SCOPES"

if [[ "$MATCHED" != "true" ]]; then
  exit 0
fi

# Extract code change
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" == "Write" ]]; then
  CODE=$(echo "$HOOK_INPUT" | jq -r '.tool_input.content // empty')
  CHANGE_DESC="Full file content"
elif [[ "$TOOL_NAME" == "Edit" ]]; then
  OLD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.old_string // empty')
  NEW=$(echo "$HOOK_INPUT" | jq -r '.tool_input.new_string // empty')
  CODE="OLD:\n$OLD\n\nNEW:\n$NEW"
  CHANGE_DESC="Edit: old_string → new_string"
else
  exit 0
fi

# Build prompt for Haiku
CONVENTIONS=$(cat "$CONVENTIONS_FILE")
PROMPT="You are a code convention enforcer. Check if this code edit violates any convention.

## Conventions
$CONVENTIONS

## File being edited
$REL_PATH ($CHANGE_DESC)

## Code
$CODE

Respond with ONLY a raw JSON object (no markdown, no explanation):
- If violations found: {\"ok\": false, \"reason\": \"each violation and how to fix\"}
- If no violations: {\"ok\": true}"

# Call claude CLI in print mode (uses OAuth, no API key needed)
RESPONSE=$(echo "$PROMPT" | claude -p --model claude-haiku-4-5-20251001 2>/dev/null || true)

if [[ -z "$RESPONSE" ]]; then
  exit 0
fi

# Parse response — look for {"ok": false, "reason": "..."}
OK=$(echo "$RESPONSE" | jq -r '.ok // true' 2>/dev/null || echo "true")
REASON=$(echo "$RESPONSE" | jq -r '.reason // empty' 2>/dev/null || true)

if [[ "$OK" == "false" && -n "$REASON" ]]; then
  echo "Convention violation: $REASON" >&2
  exit 2
fi

exit 0
