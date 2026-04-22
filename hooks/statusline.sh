#!/usr/bin/env bash
# statusline.sh — Claude Code status line: relay session, connection, unread messages
set -uo pipefail

INPUT=$(cat)
RELAY_DIR="$HOME/.claude/relay"

# Find the relay MCP process that belongs to THIS Claude Code session.
# Claude Code's PID is the parent of the relay MCP process.
# The statusline runs as a child of Claude Code, so our grandparent is Claude Code.
CLAUDE_PID=$PPID
SESSION_ID=""

for MCP_PID in $(pgrep -f "claude-relay mcp" 2>/dev/null); do
  MCP_PPID=$(ps -o ppid= -p "$MCP_PID" 2>/dev/null | tr -d ' ')
  if [[ "$MCP_PPID" == "$CLAUDE_PID" ]]; then
    HOSTNAME=$(hostname -s 2>/dev/null || hostname)
    SESSION_ID="${HOSTNAME}-${MCP_PID}"
    break
  fi
done

# Fallback: use active-session file if only one relay process
if [[ -z "$SESSION_ID" ]]; then
  ACTIVE_SESSION="$RELAY_DIR/active-session"
  if [[ -f "$ACTIVE_SESSION" ]]; then
    PID=$(jq -r '.pid // 0' "$ACTIVE_SESSION" 2>/dev/null)
    if kill -0 "$PID" 2>/dev/null; then
      SESSION_ID=$(jq -r '.session_id // empty' "$ACTIVE_SESSION" 2>/dev/null)
    fi
  fi
fi

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Check connection status (per-session)
STATUS_FILE="$RELAY_DIR/$SESSION_ID/status.json"
PEER=""
if [[ -f "$STATUS_FILE" ]]; then
  CONNECTED=$(jq -r '.connected // false' "$STATUS_FILE" 2>/dev/null)
  if [[ "$CONNECTED" == "true" ]]; then
    PEER=$(jq -r '.peer // empty' "$STATUS_FILE" 2>/dev/null)
  fi
fi

# Count unread messages for this session
UNREAD=0
INBOX_DIR="$RELAY_DIR/$SESSION_ID/inbox"
if [[ -d "$INBOX_DIR" ]]; then
  for f in "$INBOX_DIR"/msg_*.json; do
    [[ -f "$f" ]] || continue
    IS_READ=$(jq -r '.read // true' "$f" 2>/dev/null)
    if [[ "$IS_READ" == "false" ]]; then
      UNREAD=$((UNREAD + 1))
    fi
  done
fi

# Build status line
LINE="Relay: $SESSION_ID"

if [[ -n "$PEER" ]]; then
  LINE="$LINE · Paired: ${PEER}"
fi

if [[ $UNREAD -gt 0 ]]; then
  LINE="$LINE · ${UNREAD} unread"
fi

echo "$LINE"
