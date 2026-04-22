#!/usr/bin/env bash
# install.sh — Install claude-session CLI wrapper and SessionEnd hook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HOOKS_DIR="$HOME/.claude/hooks"
SKILLS_DIR="$HOME/.claude/skills"
SETTINGS="$HOME/.claude/settings.json"
MCP_JSON="$HOME/.claude/mcp.json"

echo "Installing claude-session..."

# 1. Install CLI wrapper
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/claude-session" "$BIN_DIR/claude-session"
chmod +x "$BIN_DIR/claude-session"
echo "  Installed bin/claude-session → $BIN_DIR/claude-session"

# 2. Install hooks
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/session-end.sh" "$HOOKS_DIR/session-end.sh"
chmod +x "$HOOKS_DIR/session-end.sh"
echo "  Installed hooks/session-end.sh → $HOOKS_DIR/session-end.sh"

cp "$SCRIPT_DIR/hooks/relay-session-start.sh" "$HOOKS_DIR/relay-session-start.sh"
chmod +x "$HOOKS_DIR/relay-session-start.sh"
echo "  Installed hooks/relay-session-start.sh → $HOOKS_DIR/relay-session-start.sh"

cp "$SCRIPT_DIR/hooks/relay-check-inbox.sh" "$HOOKS_DIR/relay-check-inbox.sh"
chmod +x "$HOOKS_DIR/relay-check-inbox.sh"
echo "  Installed hooks/relay-check-inbox.sh → $HOOKS_DIR/relay-check-inbox.sh"

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

  # Add relay hooks (SessionStart + UserPromptSubmit)
  python3 -c "
import json
with open('$SETTINGS') as f:
    s = json.load(f)
if 'hooks' not in s:
    s['hooks'] = {}
changed = False
if 'SessionStart' not in s['hooks']:
    s['hooks']['SessionStart'] = [
        {
            'hooks': [
                {
                    'type': 'command',
                    'command': 'bash ~/.claude/hooks/relay-session-start.sh',
                    'timeout': 10
                }
            ]
        }
    ]
    changed = True
if 'UserPromptSubmit' not in s['hooks']:
    s['hooks']['UserPromptSubmit'] = [
        {
            'hooks': [
                {
                    'type': 'command',
                    'command': 'bash ~/.claude/hooks/relay-check-inbox.sh',
                    'timeout': 10
                }
            ]
        }
    ]
    changed = True
if changed:
    with open('$SETTINGS', 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
" 2>/dev/null
  echo "  Configured relay hooks (SessionStart, UserPromptSubmit)"
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

# 5. Build and install claude-relay (Agent Connect)
if command -v go &>/dev/null && [[ -d "$SCRIPT_DIR/bridge" ]]; then
  echo ""
  echo "Building claude-relay (Agent Connect)..."
  (cd "$SCRIPT_DIR/bridge" && go build -o claude-relay . 2>&1)
  if [[ -f "$SCRIPT_DIR/bridge/claude-relay" ]]; then
    cp "$SCRIPT_DIR/bridge/claude-relay" "$BIN_DIR/claude-relay"
    chmod +x "$BIN_DIR/claude-relay"
    # Ad-hoc code sign on macOS to prevent Gatekeeper from killing the binary
    if [[ "$(uname)" == "Darwin" ]]; then
      codesign -s - "$BIN_DIR/claude-relay" 2>/dev/null || true
    fi
    echo "  Installed claude-relay → $BIN_DIR/claude-relay"
  fi
else
  echo ""
  echo "  Skipping claude-relay build (Go not installed or bridge/ missing)"
  echo "  To install Agent Connect later: cd bridge && go build -o claude-relay . && cp claude-relay ~/.local/bin/"
fi

# 6. Install relay skills
echo ""
echo "Installing relay skills..."
for skill in relay-connect relay-send relay-status; do
  if [[ -d "$SCRIPT_DIR/skills/$skill" ]]; then
    mkdir -p "$SKILLS_DIR/$skill"
    cp "$SCRIPT_DIR/skills/$skill/SKILL.md" "$SKILLS_DIR/$skill/SKILL.md"
    echo "  Installed skill: /relay-$skill → $SKILLS_DIR/$skill/"
  fi
done

# 7. Register MCP server
if [[ -f "$BIN_DIR/claude-relay" ]]; then
  echo ""
  echo "Registering claude-relay MCP server..."
  if [[ -f "$MCP_JSON" ]]; then
    if python3 -c "
import json, sys
with open('$MCP_JSON') as f:
    s = json.load(f)
if 'claude-relay' in s.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
      echo "  claude-relay MCP server already registered"
    else
      python3 -c "
import json
with open('$MCP_JSON') as f:
    s = json.load(f)
if 'mcpServers' not in s:
    s['mcpServers'] = {}
s['mcpServers']['claude-relay'] = {
    'command': '$BIN_DIR/claude-relay',
    'args': ['mcp'],
    'env': {
        'RELAY_SERVER_URL': 'wss://1zztog2jik.execute-api.us-east-1.amazonaws.com/prod'
    }
}
with open('$MCP_JSON', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
"
      echo "  Added claude-relay to $MCP_JSON"
    fi
  else
    mkdir -p "$(dirname "$MCP_JSON")"
    cat > "$MCP_JSON" << MCPEOF
{
  "mcpServers": {
    "claude-relay": {
      "command": "$BIN_DIR/claude-relay",
      "args": ["mcp"],
      "env": {
        "RELAY_SERVER_URL": "wss://1zztog2jik.execute-api.us-east-1.amazonaws.com/prod"
      }
    }
  }
}
MCPEOF
    echo "  Created $MCP_JSON with claude-relay MCP server"
  fi
fi

echo ""
echo "Done! Open a new terminal, then run:"
echo "  claude-session --help"
echo ""
echo "For Agent Connect:"
echo "  Your relay session ID will appear automatically when you start Claude Code."
echo "  Share your session ID with a peer, then /relay-connect <peer-id>"
echo "  Incoming messages appear automatically — no polling needed."
