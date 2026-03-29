#!/bin/bash
# Ship policy — operation enforcement hook for Bash commands.
# PreToolUse handler for the Bash tool. Enforces ship.policy.json rules
# on blocked commands, dependency management, git operations, and
# pre-commit quality checks.
#
# Runs IN PARALLEL with guard-orchestrator.sh. Guard only activates
# during ship-coding sessions; this activates always when a policy exists.
# No subagent bypass. No agent_id check.

set -u

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only handle Bash tool
[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$CWD" ] && exit 0
[ -z "$COMMAND" ] && exit 0

# ── LOAD POLICY ──────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/lib/policy.sh"

if ! load_policy; then
  exit 0
fi

# Merge with base policy if present
if [ -n "${BASE_POLICY_FILE:-}" ] && [ -f "$BASE_POLICY_FILE" ]; then
  POLICY=$(merge_policies)
fi

# ── HELPERS ──────────────────────────────────────────────────

deny() {
  local reason="$1"
  jq -n --arg reason "[Ship Policy] $reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

ask() {
  local reason="$1"
  jq -n --arg reason "[Ship Policy] $reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

apply_action() {
  local action="$1"
  local reason="$2"
  case "$action" in
    block) deny "$reason" ;;
    warn)  ask "$reason" ;;
    allow) return 0 ;;
    *)     deny "$reason" ;;
  esac
}

audit_violation() {
  local violation_type="$1"
  local detail_json="$2"
  log_audit "$violation_type" "$detail_json" 2>/dev/null || true
}

# ── 1. BLOCKED COMMANDS ─────────────────────────────────────
if match_regex "$COMMAND" '.operations.blocked_commands'; then
  local_action=$(get_action '.operations' "$MATCHED_ACTION")
  local_reason="${MATCHED_REASON:-Command matches blocked pattern: $MATCHED_PATTERN}"
  audit_violation "blocked_command" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg pattern "$MATCHED_PATTERN" \
    --arg action "$local_action" \
    '{command: $cmd, pattern: $pattern, action: $action}')"
  apply_action "$local_action" "$local_reason"
fi

# ── 2. DEPENDENCY MANAGEMENT ────────────────────────────────

dep_action_for() {
  local key="$1"
  local fallback="${2:-block}"
  local action
  action=$(jq -r ".operations.dependencies.${key} // empty" <<<"$POLICY" 2>/dev/null)
  if [ -z "$action" ] || [ "$action" = "null" ]; then
    action=$(jq -r '.operations.dependencies.default_action // empty' <<<"$POLICY" 2>/dev/null)
  fi
  if [ -z "$action" ] || [ "$action" = "null" ]; then
    action="$fallback"
  fi
  printf '%s\n' "$action"
}

# Detect new package install
if echo "$COMMAND" | grep -qE '(npm install|npm i |yarn add|pnpm add|pip install|cargo add|go get)\s'; then
  # Exclude flags-only invocations (e.g., npm install with no package name means install from lockfile)
  if echo "$COMMAND" | grep -qE '(npm install|npm i)\s+[^-]' || \
     echo "$COMMAND" | grep -qE '(yarn add|pnpm add|pip install|cargo add|go get)\s+[^-]'; then
    # Exclude pip install --upgrade (handled below as update)
    if ! echo "$COMMAND" | grep -qE 'pip install\s+--upgrade|pip install\s+-U'; then
      action=$(dep_action_for "new_packages" "block")
      reason="Adding new packages requires approval per policy (dependencies.new_packages=$action)"
      audit_violation "dependency_new" "$(jq -cn \
        --arg cmd "$COMMAND" \
        --arg action "$action" \
        '{command: $cmd, action: $action}')"
      apply_action "$action" "$reason"
    fi
  fi
fi

# Detect package removal
if echo "$COMMAND" | grep -qE '(npm uninstall|npm remove|npm rm|yarn remove|pnpm remove|pip uninstall|cargo remove)\s'; then
  action=$(dep_action_for "remove_packages" "block")
  reason="Removing packages requires approval per policy (dependencies.remove_packages=$action)"
  audit_violation "dependency_remove" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# Detect package update
if echo "$COMMAND" | grep -qE '(npm update|npm upgrade|yarn upgrade|pnpm update|pip install\s+--upgrade|pip install\s+-U|cargo update)\s'; then
  action=$(dep_action_for "update_packages" "block")
  reason="Updating packages requires approval per policy (dependencies.update_packages=$action)"
  audit_violation "dependency_update" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# ── 3. GIT OPERATIONS ───────────────────────────────────────

git_action_for() {
  local key="$1"
  local fallback="${2:-block}"
  local action
  action=$(jq -r ".operations.git.${key} // empty" <<<"$POLICY" 2>/dev/null)
  if [ -z "$action" ] || [ "$action" = "null" ]; then
    action=$(jq -r '.operations.git.default_action // empty' <<<"$POLICY" 2>/dev/null)
  fi
  if [ -z "$action" ] || [ "$action" = "null" ]; then
    action="$fallback"
  fi
  printf '%s\n' "$action"
}

# Force push
if echo "$COMMAND" | grep -qE 'git push.*--force|git push.*-f\b'; then
  action=$(git_action_for "force_push" "block")
  reason="Force push is restricted by policy (git.force_push=$action)"
  audit_violation "git_force_push" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# Push to main/master
if echo "$COMMAND" | grep -qE 'git push.*(main|master)'; then
  action=$(git_action_for "push_to_main" "block")
  reason="Pushing directly to main/master is restricted by policy (git.push_to_main=$action)"
  audit_violation "git_push_to_main" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# Branch deletion
if echo "$COMMAND" | grep -qE 'git branch\s+-[dD]'; then
  action=$(git_action_for "branch_delete" "block")
  reason="Branch deletion is restricted by policy (git.branch_delete=$action)"
  audit_violation "git_branch_delete" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# Amend published commits
if echo "$COMMAND" | grep -qE 'git commit.*--amend'; then
  action=$(git_action_for "amend_published" "block")
  reason="Amending commits is restricted by policy (git.amend_published=$action)"
  audit_violation "git_amend" "$(jq -cn \
    --arg cmd "$COMMAND" \
    --arg action "$action" \
    '{command: $cmd, action: $action}')"
  apply_action "$action" "$reason"
fi

# ── 4. PRE-COMMIT QUALITY CHECKS ────────────────────────────
if echo "$COMMAND" | grep -qE '^git commit\b|;\s*git commit\b|&&\s*git commit\b'; then
  PRE_COMMIT_CHECKS=$(jq -c '.quality.pre_commit // [] | .[]?' <<<"$POLICY" 2>/dev/null)
  ON_FAILURE=$(jq -r '.quality.on_failure // "block"' <<<"$POLICY" 2>/dev/null)

  if [ -n "$PRE_COMMIT_CHECKS" ]; then
    REPO_ROOT=$(_policy_repo_root)
    FAILED_CHECKS=""
    CHECK_COUNT=0
    FAIL_COUNT=0

    while IFS= read -r check_entry; do
      [ -z "$check_entry" ] && continue
      CHECK_COUNT=$((CHECK_COUNT + 1))

      check_cmd=$(jq -r '.command // empty' <<<"$check_entry" 2>/dev/null)
      check_name=$(jq -r '.name // "unnamed check"' <<<"$check_entry" 2>/dev/null)
      [ -z "$check_cmd" ] && continue

      # Run the pre-commit check from the repo root
      if ! (cd "$REPO_ROOT" && eval "$check_cmd") >/dev/null 2>&1; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_CHECKS="${FAILED_CHECKS}\n  - ${check_name}: \`${check_cmd}\`"
      fi
    done <<<"$PRE_COMMIT_CHECKS"

    if [ "$FAIL_COUNT" -gt 0 ]; then
      reason="Pre-commit quality checks failed ($FAIL_COUNT/$CHECK_COUNT):${FAILED_CHECKS}"
      audit_violation "pre_commit_failure" "$(jq -cn \
        --arg cmd "$COMMAND" \
        --arg failed "$FAIL_COUNT" \
        --arg total "$CHECK_COUNT" \
        --arg on_failure "$ON_FAILURE" \
        '{command: $cmd, failed_checks: $failed, total_checks: $total, on_failure: $on_failure}')"

      case "$ON_FAILURE" in
        block) deny "$reason" ;;
        warn)  ask "$reason" ;;
        *)     deny "$reason" ;;
      esac
    fi
  fi
fi

# ── ALL CHECKS PASSED ───────────────────────────────────────
exit 0
