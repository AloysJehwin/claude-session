#!/usr/bin/env bash
# relay-poll.sh — Polls ~/.claude/relay/inbox/ for unread messages
# Used by Claude Code to surface incoming messages from remote agents inline.

set -uo pipefail

RELAY_DIR="$HOME/.claude/relay"
INBOX_DIR="${RELAY_DIR}/inbox"

if [[ ! -d "$INBOX_DIR" ]]; then
  exit 0
fi

for f in "$INBOX_DIR"/msg_*.json; do
  [[ -f "$f" ]] || continue

  is_read=$(python3 -c "
import json, sys
with open('$f') as fh:
    msg = json.load(fh)
    print('true' if msg.get('read', False) else 'false')
" 2>/dev/null || echo "true")

  if [[ "$is_read" == "false" ]]; then
    content=$(python3 -c "
import json, sys
with open('$f') as fh:
    msg = json.load(fh)
    sender = msg.get('from', 'unknown')
    text = msg.get('content', '')
    ts = msg.get('timestamp', '')[:19]
    print(f'[From {sender} at {ts}]: {text}')
" 2>/dev/null || true)

    if [[ -n "$content" ]]; then
      echo "$content"
    fi

    # Mark as read
    python3 -c "
import json
with open('$f', 'r') as fh:
    msg = json.load(fh)
msg['read'] = True
with open('$f', 'w') as fh:
    json.dump(msg, fh, indent=2)
" 2>/dev/null || true
  fi
done

exit 0
