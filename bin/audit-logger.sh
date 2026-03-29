#!/bin/bash
# Ship audit logger — passive PostToolUse / SessionStart / SessionEnd hook handler.
# Logs file modifications, command executions, and session lifecycle events
# to .ship/audit/ as JSONL files. NEVER denies anything — exit 0 always.
#
# No subagent bypass: logs ALL tool calls regardless of caller.

set -u

INPUT=$(cat)

hook_event_name=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
session_id=$(echo "$INPUT" | jq -r '.session_id // ""')
tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""')
tool_input=$(echo "$INPUT" | jq -c '.tool_input // {}')

[ -z "$CWD" ] && exit 0

# ── LOAD POLICY ──────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/lib/policy.sh"

load_policy || exit 0

# ── CHECK AUDIT ENABLED ─────────────────────────────────────
audit_enabled=$(echo "$POLICY" | jq -r '.audit.enabled // false')
[ "$audit_enabled" != "true" ] && exit 0

# ── READ AUDIT EVENT CONFIG ─────────────────────────────────
file_modification_enabled=$(echo "$POLICY" | jq -r '.audit.events.file_modification // false')
command_execution_enabled=$(echo "$POLICY" | jq -r '.audit.events.command_execution // false')
session_lifecycle_enabled=$(echo "$POLICY" | jq -r '.audit.events.session_lifecycle // false')

# ── RETENTION CLEANUP (SessionStart only) ────────────────────
if [ "$hook_event_name" = "SessionStart" ]; then
  retention_days=$(echo "$POLICY" | jq -r '.audit.retention_days // ""')
  if [ -n "$retention_days" ] && [ "$retention_days" != "null" ]; then
    repo_root=$(_policy_repo_root)
    audit_dir="$repo_root/.ship/audit"
    if [ -d "$audit_dir" ]; then
      find "$audit_dir" -name '*.jsonl' -type f -mtime +"$retention_days" -delete 2>/dev/null || true
    fi
  fi
fi

# ── LOG FILE MODIFICATIONS (Write / Edit) ────────────────────
if [ "$file_modification_enabled" = "true" ]; then
  if [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path // ""')
    detail=$(jq -cn --arg tool "$tool_name" --arg file_path "$file_path" \
      '{tool: $tool, file_path: $file_path}')
    log_audit "file_modification" "$detail"
  fi
fi

# ── LOG COMMAND EXECUTIONS (Bash) ────────────────────────────
if [ "$command_execution_enabled" = "true" ]; then
  if [ "$tool_name" = "Bash" ]; then
    command_raw=$(echo "$tool_input" | jq -r '.command // ""')
    # Truncate to 200 characters
    command_truncated=$(printf '%.200s' "$command_raw")
    detail=$(jq -cn --arg command "$command_truncated" \
      '{command: $command}')
    log_audit "command_execution" "$detail"
  fi
fi

# ── LOG SESSION LIFECYCLE (SessionStart / SessionEnd) ────────
if [ "$session_lifecycle_enabled" = "true" ]; then
  if [ "$hook_event_name" = "SessionStart" ] || [ "$hook_event_name" = "SessionEnd" ]; then
    detail=$(jq -cn --arg reason "$hook_event_name" \
      '{reason: $reason}')
    log_audit "session_lifecycle" "$detail"
  fi
fi

exit 0
