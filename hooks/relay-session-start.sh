#!/usr/bin/env bash
# relay-session-start.sh — Show relay session ID at Claude Code startup
set -uo pipefail

RELAY_BIN="$HOME/.local/bin/claude-relay"
if [[ ! -x "$RELAY_BIN" ]]; then
  exit 0
fi

exec "$RELAY_BIN" mcp-status 2>/dev/null
