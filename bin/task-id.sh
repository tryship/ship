#!/bin/bash
# Generate a deterministic task ID from a description string.
# Usage: task-id.sh <description>
# Output: task_id slug on stdout (no newline)
#
# Rules:
#   - lowercase
#   - non-alphanumeric → hyphen
#   - collapse consecutive hyphens
#   - strip leading/trailing hyphens
#   - truncate to 60 characters

set -u

DESCRIPTION="${1:-}"
if [ -z "$DESCRIPTION" ]; then
  echo "Usage: task-id.sh <description>" >&2
  exit 1
fi

echo -n "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-60
