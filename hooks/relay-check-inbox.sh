#!/usr/bin/env bash
# relay-check-inbox.sh — Surface unread relay messages before each prompt
set -uo pipefail

RELAY_BIN="$HOME/.local/bin/claude-relay"
if [[ ! -x "$RELAY_BIN" ]]; then
  exit 0
fi

"$RELAY_BIN" check-inbox 2>/dev/null
exit 0
