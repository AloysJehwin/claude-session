#!/usr/bin/env bash
# uninstall.sh — Remove claude-session CLI wrapper and SessionEnd hook
set -euo pipefail

BIN_FILE="$HOME/.local/bin/claude-session"
HOOK_FILE="$HOME/.claude/hooks/session-end.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "Uninstalling claude-session..."

# 1. Remove CLI wrapper
if [[ -f "$BIN_FILE" ]]; then
  rm "$BIN_FILE"
  echo "  Removed $BIN_FILE"
else
  echo "  $BIN_FILE not found (skipped)"
fi

# 2. Remove hook script
if [[ -f "$HOOK_FILE" ]]; then
  rm "$HOOK_FILE"
  echo "  Removed $HOOK_FILE"
else
  echo "  $HOOK_FILE not found (skipped)"
fi

# 3. Remove SessionEnd hook from settings.json
if [[ -f "$SETTINGS" ]]; then
  if python3 -c "
import json
with open('$SETTINGS') as f:
    s = json.load(f)
if 'hooks' in s and 'SessionEnd' in s['hooks']:
    del s['hooks']['SessionEnd']
    if not s['hooks']:
        del s['hooks']
    with open('$SETTINGS', 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
    print('  Removed SessionEnd hook from settings.json')
else:
    print('  No SessionEnd hook found in settings.json (skipped)')
" 2>/dev/null; then
    true
  else
    echo "  Could not update settings.json (check manually)"
  fi
fi

echo ""
echo "Done! Session log files in ~/.claude/projects/*/memory/sessions/ are preserved."
echo "Delete them manually if you want a full cleanup."
