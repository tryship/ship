#!/usr/bin/env bash
# Ship safety rule checker — PreToolUse command hook.
# Reads hook JSON from stdin, evaluates .ship/rules/safety.*.md rules
# using regex matching. No AI needed — pure deterministic checks.
#
# Requires: jq
# Returns: exit 0 (pass) or exit 2 + stderr message (block)
set -uo pipefail

HOOK_INPUT=$(cat)

# Find safety rules
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RULES_DIR="$REPO_ROOT/.ship/rules"

# No rules directory or no safety rules → pass
if [[ ! -d "$RULES_DIR" ]]; then
  exit 0
fi

RULE_FILES=$(find "$RULES_DIR" -name 'safety.*.md' 2>/dev/null)
if [[ -z "$RULE_FILES" ]]; then
  exit 0
fi

# Extract tool info from hook input
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
NEW_STRING=$(echo "$HOOK_INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')

BLOCKED=false
MESSAGES=""

while IFS= read -r rule_file; do
  [[ -z "$rule_file" ]] && continue

  # Parse YAML frontmatter (between --- markers)
  FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$rule_file" | sed '1d;$d')

  # Check enabled
  ENABLED=$(echo "$FRONTMATTER" | grep '^enabled:' | sed 's/enabled: *//' | tr -d ' ')
  [[ "$ENABLED" == "false" ]] && continue

  # Check event type
  EVENT=$(echo "$FRONTMATTER" | grep '^event:' | sed 's/event: *//' | tr -d ' ')
  case "$EVENT" in
    file)
      [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]] && continue
      ;;
    bash)
      [[ "$TOOL_NAME" != "Bash" ]] && continue
      ;;
    all) ;;
    *) continue ;;
  esac

  # Check action type
  ACTION=$(echo "$FRONTMATTER" | grep '^action:' | sed 's/action: *//' | tr -d ' ')
  [[ -z "$ACTION" ]] && ACTION="warn"

  # Extract conditions and evaluate
  # Simple approach: parse field/pattern pairs from conditions
  MATCH=true
  while IFS= read -r condition_line; do
    [[ -z "$condition_line" ]] && continue

    FIELD=$(echo "$condition_line" | grep -oP 'field:\s*\K\S+' || true)
    PATTERN=$(echo "$condition_line" | grep -oP 'pattern:\s*\K.*' || true)
    [[ -z "$FIELD" || -z "$PATTERN" ]] && continue

    # Get the value to check
    case "$FIELD" in
      file_path) VALUE="$FILE_PATH" ;;
      command) VALUE="$COMMAND" ;;
      new_string|new_text|content) VALUE="$NEW_STRING" ;;
      *) VALUE="" ;;
    esac

    # Regex match
    if [[ -n "$VALUE" ]] && echo "$VALUE" | grep -qiE "$PATTERN" 2>/dev/null; then
      : # match found, continue checking other conditions
    else
      MATCH=false
      break
    fi
  done < <(echo "$FRONTMATTER" | grep -A2 '^\s*-\s*field:' | paste - - - | tr '\t' ' ')

  if [[ "$MATCH" == "true" ]]; then
    # Extract message (everything after second ---)
    MESSAGE=$(sed -n '/^---$/,/^---$/!p' "$rule_file" | sed '/^$/d' | head -5)
    RULE_NAME=$(echo "$FRONTMATTER" | grep '^name:' | sed 's/name: *//')

    if [[ "$ACTION" == "block" ]]; then
      BLOCKED=true
      MESSAGES="${MESSAGES}[BLOCKED] ${RULE_NAME}: ${MESSAGE}\n"
    else
      MESSAGES="${MESSAGES}[WARNING] ${RULE_NAME}: ${MESSAGE}\n"
    fi
  fi
done <<< "$RULE_FILES"

if [[ "$BLOCKED" == "true" ]]; then
  echo -e "$MESSAGES" >&2
  exit 2
elif [[ -n "$MESSAGES" ]]; then
  echo -e "$MESSAGES" >&2
  exit 0
fi

exit 0
