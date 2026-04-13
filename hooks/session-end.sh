#!/usr/bin/env bash
# session-end.sh — Claude Code SessionEnd hook
# Auto-captures session context when a Claude Code session ends.
#
# Receives JSON on stdin: { "session_id": "...", "cwd": "...", "transcript_path": "..." }
# Writes/updates a session log file in the project's memory/sessions/ directory.

set -uo pipefail

CLAUDE_BASE_DIR="$HOME/.claude"

# ---------------------------------------------------------------------------
# Read hook input
# ---------------------------------------------------------------------------

INPUT=$(cat)

CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")

# Fallback: if cwd not in input, use the env var or current dir
if [[ -z "$CWD" ]]; then
  CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

ENCODED=$(echo "$CWD" | sed 's|/|-|g')
MEM_DIR="${CLAUDE_BASE_DIR}/projects/${ENCODED}/memory"
SESSIONS_DIR="${MEM_DIR}/sessions"
MEMORY_MD="${MEM_DIR}/MEMORY.md"

# Only proceed if this project has a memory system set up
if [[ ! -d "$MEM_DIR" ]]; then
  exit 0
fi

mkdir -p "$SESSIONS_DIR"

# ---------------------------------------------------------------------------
# Determine which session file to update
# ---------------------------------------------------------------------------

SESSION_FILE="${CLAUDE_SESSION_FILE:-}"

# If no session file was set by the wrapper, find or create one
if [[ -z "$SESSION_FILE" ]] || [[ ! -f "$SESSION_FILE" ]]; then
  # Find today's most recent session file
  TODAY=$(date "+%Y-%m-%d")
  SESSION_FILE=$(ls -1 "$SESSIONS_DIR"/session_${TODAY}*.md 2>/dev/null | sort | tail -1)

  # If none found, create one
  if [[ -z "$SESSION_FILE" ]]; then
    TS=$(date "+%Y-%m-%d_%H%M%S")
    SESSION_FILE="${SESSIONS_DIR}/session_${TS}.md"
  fi
fi

# ---------------------------------------------------------------------------
# Gather context: git changes since session started
# ---------------------------------------------------------------------------

GIT_CHANGES=""
GIT_LOG=""

if [[ -d "${CWD}/.git" ]] || git -C "$CWD" rev-parse --git-dir &>/dev/null 2>&1; then
  GIT_CHANGES=$(cd "$CWD" && git diff --stat HEAD 2>/dev/null | tail -5) || true
  GIT_LOG=$(cd "$CWD" && git log --oneline -5 2>/dev/null) || true
fi

# ---------------------------------------------------------------------------
# Write or update session file
# ---------------------------------------------------------------------------

DISPLAY_DATE=$(date "+%Y-%m-%d %H:%M:%S")
TS_NAME=$(basename "$SESSION_FILE" .md)

if [[ -f "$SESSION_FILE" ]]; then
  # Update existing file: replace the "What changed" section
  # Only update if the current content is a placeholder
  if grep -q '\[None yet\]\|\[Review git diff\]\|\[Session ended\]' "$SESSION_FILE" 2>/dev/null; then
    # Build the changes section
    CHANGES_CONTENT="## What changed"
    if [[ -n "$GIT_LOG" ]]; then
      CHANGES_CONTENT="${CHANGES_CONTENT}
Recent commits:
\`\`\`
${GIT_LOG}
\`\`\`"
    fi
    if [[ -n "$GIT_CHANGES" ]]; then
      CHANGES_CONTENT="${CHANGES_CONTENT}
Uncommitted changes:
\`\`\`
${GIT_CHANGES}
\`\`\`"
    fi
    if [[ -z "$GIT_LOG" ]] && [[ -z "$GIT_CHANGES" ]]; then
      CHANGES_CONTENT="${CHANGES_CONTENT}
No git changes detected."
    fi

    # Use python for reliable multiline replacement
    python3 -c "
import re, sys

with open('$SESSION_FILE', 'r') as f:
    content = f.read()

changes = '''$CHANGES_CONTENT'''

# Replace the 'What changed' section
content = re.sub(
    r'## What changed.*?(?=\n## |\Z)',
    changes.strip() + '\n\n',
    content,
    flags=re.DOTALL
)

# Update description if still placeholder
content = re.sub(
    r'description: Session started at .*',
    'description: Session ended at $DISPLAY_DATE',
    content
)

with open('$SESSION_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || true
  fi
else
  # Create new session file
  cat > "$SESSION_FILE" << ENDOFFILE
---
name: ${TS_NAME}
description: Session ended at ${DISPLAY_DATE}
type: project
---

## Summary
[Session summary pending — to be filled in next session]

## Decisions
[Review conversation for decisions made]

## What changed
$(if [[ -n "$GIT_LOG" ]]; then
  echo "Recent commits:"
  echo '```'
  echo "$GIT_LOG"
  echo '```'
fi)
$(if [[ -n "$GIT_CHANGES" ]]; then
  echo "Uncommitted changes:"
  echo '```'
  echo "$GIT_CHANGES"
  echo '```'
fi)
$(if [[ -z "$GIT_LOG" ]] && [[ -z "$GIT_CHANGES" ]]; then
  echo "No git changes detected."
fi)

## Open / Next
[To be determined]
ENDOFFILE

  # Update MEMORY.md index
  if [[ -f "$MEMORY_MD" ]]; then
    ENTRY="- [${TS_NAME}](sessions/${TS_NAME}.md) — session log"
    if ! grep -qF "$TS_NAME" "$MEMORY_MD" 2>/dev/null; then
      if grep -q "^## Session Logs" "$MEMORY_MD"; then
        # macOS sed
        sed -i '' "/^## Session Logs/a\\
${ENTRY}" "$MEMORY_MD" 2>/dev/null || \
        # GNU sed fallback
        sed -i "/^## Session Logs/a\\${ENTRY}" "$MEMORY_MD" 2>/dev/null || \
        echo "$ENTRY" >> "$MEMORY_MD"
      else
        printf "\n## Session Logs\n%s\n" "$ENTRY" >> "$MEMORY_MD"
      fi
    fi
  fi
fi

exit 0
