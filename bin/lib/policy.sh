#!/bin/bash
set -u

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "bin/lib/policy.sh must be sourced, not executed directly." >&2
  exit 1
fi

POLICY_ROOT="${POLICY_ROOT:-}"
POLICY_FILE="${POLICY_FILE:-}"
BASE_POLICY_FILE="${BASE_POLICY_FILE:-}"
POLICY="${POLICY:-}"
MATCHED_PATTERN="${MATCHED_PATTERN:-}"
MATCHED_REASON="${MATCHED_REASON:-}"
MATCHED_ACTION="${MATCHED_ACTION:-}"

_policy_repo_root() {
  local start_dir
  local repo_root

  if [ -n "${POLICY_ROOT:-}" ] && [ -d "$POLICY_ROOT" ]; then
    printf '%s\n' "$POLICY_ROOT"
    return 0
  fi

  start_dir="${CWD:-$PWD}"
  if repo_root=$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null); then
    POLICY_ROOT="$repo_root"
  else
    POLICY_ROOT="$start_dir"
  fi

  printf '%s\n' "$POLICY_ROOT"
}

_policy_rules() {
  local jq_array_path="$1"

  if [ -z "${POLICY:-}" ]; then
    return 0
  fi

  jq -c "${jq_array_path} // [] | .[]?" <<<"$POLICY" 2>/dev/null
}

load_policy() {
  local repo_root

  repo_root=$(_policy_repo_root)
  POLICY_FILE="$repo_root/.ship/ship.policy.json"
  BASE_POLICY_FILE=""

  if [ -f "$repo_root/.ship/ship.policy.base.json" ]; then
    BASE_POLICY_FILE="$repo_root/.ship/ship.policy.base.json"
  fi

  if [ ! -f "$POLICY_FILE" ]; then
    POLICY=""
    return 1
  fi

  POLICY=$(cat "$POLICY_FILE")
  return 0
}

merge_policies() {
  local base_json=""
  local repo_json=""

  if [ -n "${BASE_POLICY_FILE:-}" ] && [ -f "$BASE_POLICY_FILE" ]; then
    base_json=$(cat "$BASE_POLICY_FILE")
  fi

  if [ -n "${POLICY:-}" ]; then
    repo_json="$POLICY"
  elif [ -n "${POLICY_FILE:-}" ] && [ -f "$POLICY_FILE" ]; then
    repo_json=$(cat "$POLICY_FILE")
  fi

  if [ -z "$base_json" ] && [ -z "$repo_json" ]; then
    printf '{}\n'
    return 0
  fi

  if [ -z "$base_json" ]; then
    printf '%s\n' "$repo_json"
    return 0
  fi

  if [ -z "$repo_json" ]; then
    printf '%s\n' "$base_json"
    return 0
  fi

  jq -n \
    --argjson base "$base_json" \
    --argjson repo "$repo_json" '
      # Higher rank means stricter policy and therefore wins during merges.
      def action_rank($value):
        if $value == "allow" then 0
        elif $value == "warn" then 1
        elif $value == "block" then 2
        else -1
        end;

      def stricter_action($left; $right):
        if $left == null then $right
        elif $right == null then $left
        elif action_rank($left) >= action_rank($right) then $left
        else $right
        end;

      def append_unique($items):
        reduce $items[] as $item
          ([];
            if any(.[]; . == $item) then . else . + [$item] end
          );

      def union_arrays($left; $right):
        append_unique(($left // []) + ($right // []));

      # Merge recursively, but keep org-level constraints stronger than repo-level overrides.
      def merge_nodes($base; $repo; $path):
        if $base == null then $repo
        elif $repo == null then $base
        elif (($path | length) >= 2 and $path[0] == "workflow" and $path[1] == "phases"
          and ($base | type) == "string" and ($repo | type) == "string") then
          if $base == "required" or $repo == "required" then "required" else $repo end
        elif ($base | type) == "object" and ($repo | type) == "object" then
          reduce ((($base | keys_unsorted) + ($repo | keys_unsorted)) | unique[]) as $key
            ({};
              .[$key] = (
                if $key == "action" then
                  stricter_action($base[$key]; $repo[$key])
                elif $key == "enabled" and $base[$key] == true then
                  true
                elif ($key == "read_only" or $key == "no_access" or $key == "blocked_commands" or $key == "pre_commit")
                  and (($base[$key] | type) == "array" or ($repo[$key] | type) == "array") then
                  union_arrays($base[$key]; $repo[$key])
                else
                  merge_nodes($base[$key]; $repo[$key]; $path + [$key])
                end
              )
            )
        elif ($base | type) == "array" and ($repo | type) == "array" then
          $repo
        else
          $repo
        end;

      merge_nodes($base; $repo; [])
    '
}

match_glob() {
  local file_path="$1"
  local jq_array_path="$2"
  local repo_root
  local relative_path
  local rule
  local pattern
  local extglob_was_enabled=0
  local -a candidates

  MATCHED_PATTERN=""
  MATCHED_REASON=""
  MATCHED_ACTION=""

  [ -z "$file_path" ] && return 1

  repo_root=$(_policy_repo_root)
  relative_path="${file_path#./}"
  candidates=("$file_path")

  # Callers may pass repo-relative or absolute paths, so test both forms.
  if [ "$relative_path" != "$file_path" ]; then
    candidates+=("$relative_path")
  fi

  if [[ "$file_path" == "$repo_root/"* ]]; then
    candidates+=("${file_path#$repo_root/}")
  fi

  shopt -q extglob && extglob_was_enabled=1
  shopt -s extglob

  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    pattern=$(jq -r '.pattern // empty' <<<"$rule")
    [ -z "$pattern" ] && continue

    for candidate in "${candidates[@]}"; do
      # Convert ** to work as recursive match: "src/core/**" → prefix "src/core/"
      local match=0
      if [[ "$pattern" == *"/**" ]]; then
        local prefix="${pattern%/**}/"
        [[ "$candidate" == "$prefix"* ]] && match=1
      elif [[ "$candidate" == $pattern ]]; then
        match=1
      fi
      if [ "$match" -eq 1 ]; then
        MATCHED_PATTERN="$pattern"
        MATCHED_REASON=$(jq -r '.reason // empty' <<<"$rule")
        MATCHED_ACTION=$(jq -r '.action // empty' <<<"$rule")
        [ "$extglob_was_enabled" -eq 1 ] || shopt -u extglob
        return 0
      fi
    done
  done < <(_policy_rules "$jq_array_path")

  [ "$extglob_was_enabled" -eq 1 ] || shopt -u extglob
  return 1
}

match_regex() {
  local command="$1"
  local jq_array_path="$2"
  local rule
  local pattern
  local status

  MATCHED_PATTERN=""
  MATCHED_REASON=""
  MATCHED_ACTION=""

  [ -z "$command" ] && return 1

  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    pattern=$(jq -r '.pattern // empty' <<<"$rule")
    [ -z "$pattern" ] && continue

    [[ "$command" =~ $pattern ]]
    status=$?
    if [ "$status" -eq 0 ]; then
      MATCHED_PATTERN="$pattern"
      MATCHED_REASON=$(jq -r '.reason // empty' <<<"$rule")
      MATCHED_ACTION=$(jq -r '.action // empty' <<<"$rule")
      return 0
    fi
  done < <(_policy_rules "$jq_array_path")

  return 1
}

get_action() {
  local section_path="$1"
  local rule_action="${2:-}"
  local current_path
  local resolved_action

  if [ -n "$rule_action" ] && [ "$rule_action" != "null" ]; then
    printf '%s\n' "$rule_action"
    return 0
  fi

  if [ -z "${POLICY:-}" ] || [ -z "$section_path" ]; then
    printf 'block\n'
    return 0
  fi

  current_path="$section_path"
  while [ -n "$current_path" ]; do
    resolved_action=$(jq -r "${current_path}.default_action // empty" <<<"$POLICY" 2>/dev/null)
    if [ -n "$resolved_action" ] && [ "$resolved_action" != "null" ]; then
      printf '%s\n' "$resolved_action"
      return 0
    fi

    case "$current_path" in
      *.*) current_path="${current_path%.*}" ;;
      *) break ;;
    esac
  done

  printf 'block\n'
}

log_audit() {
  local event_type="$1"
  local detail_json="$2"
  local repo_root
  local audit_dir
  local audit_file
  local timestamp
  local day_stamp
  local session_id
  local developer

  repo_root=$(_policy_repo_root)
  audit_dir="$repo_root/.ship/audit"
  day_stamp=$(date -u '+%Y-%m-%d')
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  audit_file="$audit_dir/$day_stamp.jsonl"
  session_id="${CLAUDE_CODE_SESSION_ID:-}"
  developer=$(git -C "$repo_root" config user.name 2>/dev/null || true)

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
    }' >>"$audit_file"
}
