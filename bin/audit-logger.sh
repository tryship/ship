#!/bin/bash
# Ship audit logger — standalone hook handler.
# Logs file modifications, command executions, and optional session lifecycle
# events to .ship/audit/ as JSONL. Never denies anything and always exits 0.
#
# Reads optional config from .ship/rules/rules.json.

set -u

INPUT=$(cat)

hook_event_name=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
session_id=$(echo "$INPUT" | jq -r '.session_id // ""')
tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""')
tool_input=$(echo "$INPUT" | jq -c '.tool_input // {}')

[ -z "$CWD" ] && exit 0

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
RULES_JSON="$REPO_ROOT/.ship/rules/rules.json"

audit_enabled="true"
file_modification_enabled="true"
command_execution_enabled="true"
session_lifecycle_enabled="false"

if [ -f "$RULES_JSON" ]; then
  audit_enabled=$(jq -r '.audit.enabled // true' "$RULES_JSON" 2>/dev/null || echo "true")
  file_modification_enabled=$(jq -r '.audit.events.file_modification // true' "$RULES_JSON" 2>/dev/null || echo "true")
  command_execution_enabled=$(jq -r '.audit.events.command_execution // true' "$RULES_JSON" 2>/dev/null || echo "true")
  session_lifecycle_enabled=$(jq -r '.audit.events.session_lifecycle // false' "$RULES_JSON" 2>/dev/null || echo "false")
fi

[ "$audit_enabled" != "true" ] && exit 0

log_audit() {
  local event_type="$1"
  local detail_json="$2"
  local audit_dir="$REPO_ROOT/.ship/audit"
  local day_stamp
  local timestamp
  local developer

  day_stamp=$(date -u '+%Y-%m-%d')
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  developer=$(git -C "$REPO_ROOT" config user.name 2>/dev/null || true)

  mkdir -p "$audit_dir"

  jq -cn \
    --arg timestamp "$timestamp" \
    --arg session_id "$session_id" \
    --arg event_type "$event_type" \
    --arg developer "$developer" \
    --argjson detail "$detail_json" \
    '{
      timestamp: $timestamp,
      session_id: $session_id,
      event_type: $event_type,
      detail: $detail,
      developer: $developer
    }' >>"$audit_dir/$day_stamp.jsonl"
}

if [ "$file_modification_enabled" = "true" ]; then
  if [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path // ""')
    detail=$(jq -cn --arg tool "$tool_name" --arg file_path "$file_path" \
      '{tool: $tool, file_path: $file_path}')
    log_audit "file_modification" "$detail"
  fi
fi

if [ "$command_execution_enabled" = "true" ]; then
  if [ "$tool_name" = "Bash" ]; then
    command_raw=$(echo "$tool_input" | jq -r '.command // ""')
    command_truncated=$(printf '%.200s' "$command_raw")
    detail=$(jq -cn --arg command "$command_truncated" \
      '{command: $command}')
    log_audit "command_execution" "$detail"
  fi
fi

if [ "$session_lifecycle_enabled" = "true" ]; then
  if [ "$hook_event_name" = "SessionStart" ] || [ "$hook_event_name" = "SessionEnd" ]; then
    detail=$(jq -cn --arg reason "$hook_event_name" \
      '{reason: $reason}')
    log_audit "session_lifecycle" "$detail"
  fi
fi

exit 0
