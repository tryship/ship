#!/usr/bin/env bash
# Ship auth headers helper for MCP server integration.
# Outputs JSON headers for authenticated Ship API requests.
#
# Future usage in .mcp.json (when Ship MCP server is available):
#   "ship": {
#     "type": "http",
#     "url": "https://api.ship.tech/mcp",
#     "headersHelper": "${CLAUDE_PLUGIN_ROOT}/scripts/auth-headers.sh"
#   }
set -u

# Resolve credential path from Ship config (matches Ship CLI's resolution)
_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ship"
_CRED_FILE="$_CONFIG_DIR/credentials.json"

# Check if config.yaml specifies a different credentials file
if [ -f "$_CONFIG_DIR/config.yaml" ]; then
  _CUSTOM_CRED=$(sed -n 's/^[[:space:]]*credentials:[[:space:]]*//p' "$_CONFIG_DIR/config.yaml" | head -1)
  if [ -n "$_CUSTOM_CRED" ]; then
    case "$_CUSTOM_CRED" in
      /*) _CRED_FILE="$_CUSTOM_CRED" ;;
      *)  _CRED_FILE="$_CONFIG_DIR/$_CUSTOM_CRED" ;;
    esac
  fi
fi

# No credentials file → empty headers
if [ ! -f "$_CRED_FILE" ]; then
  echo '{}'
  exit 0
fi

# Extract token, check if present and not expired
_TOKEN=$(jq -r '.token // empty' "$_CRED_FILE")
if [ -z "$_TOKEN" ]; then
  echo '{}'
  exit 0
fi

# Check expiry
_EXPIRES=$(jq -r '.expires_at // empty' "$_CRED_FILE")
if [ -n "$_EXPIRES" ]; then
  # Strip fractional seconds and timezone suffix, parse as UTC
  _TS="${_EXPIRES%%.*}"
  _TS="${_TS%%Z}"
  _TS="${_TS%%+*}"
  _EXP_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$_TS" "+%s" 2>/dev/null || echo "0")
  _NOW_EPOCH=$(date "+%s")
  if [ "$_EXP_EPOCH" -gt 0 ] && [ "$_NOW_EPOCH" -gt "$_EXP_EPOCH" ]; then
    echo '{}'
    exit 0
  fi
fi

jq -n --arg token "$_TOKEN" '{"Authorization": ("Bearer " + $token)}'
