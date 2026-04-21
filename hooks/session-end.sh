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
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")

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
# Extract a topic tag from the first user message in the transcript
# ---------------------------------------------------------------------------

SESSION_TAG=""
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  SESSION_TAG=$(python3 -c "
import json, sys
try:
    with open('$TRANSCRIPT_PATH', 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if obj.get('type') != 'user':
                continue
            msg = obj.get('message', {})
            content = msg.get('content', '')
            text = ''
            if isinstance(content, list):
                for c in content:
                    if c.get('type') == 'text':
                        text = c['text']
                        break
            elif isinstance(content, str):
                text = content
            if text:
                text = ' '.join(text.split())
                if len(text) > 50:
                    text = text[:50].rsplit(' ', 1)[0]
                print(text.lower())
            break
except Exception:
    pass
" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# If the session had no user messages, clean up the empty session file
# ---------------------------------------------------------------------------

HAS_USER_MSG=""
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  HAS_USER_MSG=$(python3 -c "
import json
try:
    with open('$TRANSCRIPT_PATH', 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if obj.get('type') == 'user':
                print('yes')
                break
except Exception:
    pass
" 2>/dev/null || true)
fi

if [[ -z "$HAS_USER_MSG" ]]; then
  SESSION_FILE="${CLAUDE_SESSION_FILE:-}"
  if [[ -n "$SESSION_FILE" ]] && [[ -f "$SESSION_FILE" ]]; then
    BASENAME=$(basename "$SESSION_FILE" .md)
    rm -f "$SESSION_FILE"
    if [[ -f "$MEMORY_MD" ]]; then
      grep -vF "$BASENAME" "$MEMORY_MD" > "${MEMORY_MD}.tmp" 2>/dev/null && \
        mv "${MEMORY_MD}.tmp" "$MEMORY_MD" || \
        rm -f "${MEMORY_MD}.tmp"
    fi
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Determine which session file to update
# ---------------------------------------------------------------------------

SESSION_FILE="${CLAUDE_SESSION_FILE:-}"

# If no session file was set by the wrapper, find or create one
if [[ -z "$SESSION_FILE" ]] || [[ ! -f "$SESSION_FILE" ]]; then
  # Find today's most recent session file
  TODAY=$(date "+%Y-%m-%d")
  SESSION_FILE=$(ls -1 "$SESSIONS_DIR"/session_${TODAY}*.md 2>/dev/null | sort | tail -1 || true)

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

# Add session_id to frontmatter if not already present
session_id = '''$SESSION_ID'''
if session_id and 'session_id:' not in content:
    content = content.replace('type: project', 'type: project\nsession_id: ' + session_id, 1)

# Add tag to frontmatter if not already present
tag = '''$SESSION_TAG'''
if tag and 'tag:' not in content:
    content = content.replace('type: project', 'type: project\ntag: ' + tag, 1)

# Update name to include tag
if tag:
    content = re.sub(
        r'name: Session (\S+)',
        r'name: Session \1 — ' + tag,
        content
    )

with open('$SESSION_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || true
  fi
else
  # Create new session file
  # Build name with optional tag
  SESSION_NAME="${TS_NAME}"
  if [[ -n "$SESSION_TAG" ]]; then
    SESSION_NAME="${TS_NAME} — ${SESSION_TAG}"
  fi

  # Build frontmatter lines
  FM_EXTRA=""
  if [[ -n "$SESSION_ID" ]]; then FM_EXTRA="${FM_EXTRA}session_id: ${SESSION_ID}
"; fi
  if [[ -n "$SESSION_TAG" ]]; then FM_EXTRA="${FM_EXTRA}tag: ${SESSION_TAG}
"; fi

  cat > "$SESSION_FILE" << ENDOFFILE
---
name: ${SESSION_NAME}
description: Session ended at ${DISPLAY_DATE}
type: project
${FM_EXTRA}---

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
    if [[ -n "$SESSION_TAG" ]]; then
      ENTRY="- [${TS_NAME}](sessions/${TS_NAME}.md) — ${SESSION_TAG}"
    else
      ENTRY="- [${TS_NAME}](sessions/${TS_NAME}.md) — session log"
    fi
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
