#!/usr/bin/env bash
# install.sh — Install claude-session CLI wrapper and SessionEnd hook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing claude-session..."

# 1. Install CLI wrapper
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/claude-session" "$BIN_DIR/claude-session"
chmod +x "$BIN_DIR/claude-session"
echo "  Installed bin/claude-session → $BIN_DIR/claude-session"

# 2. Install SessionEnd hook
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/session-end.sh" "$HOOKS_DIR/session-end.sh"
chmod +x "$HOOKS_DIR/session-end.sh"
echo "  Installed hooks/session-end.sh → $HOOKS_DIR/session-end.sh"

# 3. Add SessionEnd hook to settings.json
if [[ -f "$SETTINGS" ]]; then
  # Check if hook already exists
  if python3 -c "
import json, sys
with open('$SETTINGS') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
if 'SessionEnd' in hooks:
    sys.exit(0)  # already configured
sys.exit(1)
" 2>/dev/null; then
    echo "  SessionEnd hook already configured in settings.json"
  else
    # Merge hook into existing settings
    python3 -c "
import json
with open('$SETTINGS') as f:
    s = json.load(f)
if 'hooks' not in s:
    s['hooks'] = {}
s['hooks']['SessionEnd'] = [
    {
        'hooks': [
            {
                'type': 'command',
                'command': 'bash ~/.claude/hooks/session-end.sh',
                'timeout': 30
            }
        ]
    }
]
with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
"
    echo "  Added SessionEnd hook to $SETTINGS"
  fi
else
  # Create settings.json with hook
  mkdir -p "$(dirname "$SETTINGS")"
  cat > "$SETTINGS" << 'EOF'
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/session-end.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
  echo "  Created $SETTINGS with SessionEnd hook"
fi

# 4. Ensure ~/.local/bin is on PATH
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SHELL_RC=""

if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  if ! grep -qF '.local/bin' "$SHELL_RC" 2>/dev/null; then
    printf '\n# claude-session\n%s\n' "$PATH_LINE" >> "$SHELL_RC"
    echo "  Added ~/.local/bin to PATH in $SHELL_RC"
  else
    echo "  ~/.local/bin already on PATH"
  fi
else
  echo "  WARNING: Could not find .zshrc or .bashrc"
  echo "  Add this to your shell config manually:"
  echo "    $PATH_LINE"
fi

echo ""
echo "Done! Open a new terminal, then run:"
echo "  claude-session --help"
