# How It Works

## Session storage

Sessions are stored per-project in Claude Code's own directory structure:

**macOS / Linux:**
```
~/.claude/projects/<encoded-project-path>/memory/
├── MEMORY.md              ← index of all sessions
└── sessions/
    ├── session_2026-04-11_143022.md
    ├── session_2026-04-12_091500.md
    └── ...
```

**Windows:**
```
%USERPROFILE%\.claude\projects\<encoded-project-path>\memory\
├── MEMORY.md
└── sessions\
    ├── session_2026-04-11_143022.md
    └── ...
```

The project path is encoded so sessions are automatically scoped to each project directory:
- macOS/Linux: `/Users/foo/project` → `-Users-foo-project`
- Windows: `C:\Users\foo\project` → `C-Users-foo-project`

## Session file format

```markdown
---
name: Session 2026-04-11_143022 — discuss auth refactor approach
description: Session ended at 2026-04-11 14:35:00
type: project
session_id: 550e8400-e29b-41d4-a716-446655440000
tag: discuss auth refactor approach
---

## Summary
- Discussed auth refactor approach
- Decided on JWT with refresh tokens

## Decisions
- Use RS256 for JWT signing
- Store refresh tokens in httpOnly cookies

## What changed
Recent commits:
  abc1234 feat: add JWT auth middleware
  def5678 feat: add refresh token endpoint

## Open / Next
- Add token revocation endpoint
- Write integration tests
```

- **`session_id`** — the Claude Code conversation ID, used by `--load` to resume the exact conversation (via `claude --resume`)
- **`tag`** — auto-generated from your first message in the session, shown in `--list` output for quick identification

## Context injection

When resuming, the wrapper extracts the **Summary**, **Decisions**, and **Open / Next** sections and injects them via `--append-system-prompt`. The context is truncated to 2000 characters to avoid bloating the system prompt.

When using `--load`, the wrapper reads the `session_id` from the session file and uses `claude --resume <id>` to reopen the exact conversation. If the session file predates this feature (no `session_id`), it falls back to `claude --continue`.

## Session tags

Each session is automatically tagged with a short topic derived from your first message. This tag:
- Appears in `--list` output next to the date for easy identification
- Is stored in the session file frontmatter as `tag:`
- Is included in the `MEMORY.md` index

## SessionEnd hook

The hook fires automatically when any Claude Code session ends. It:
- Reads the session ID, working directory, and transcript path from the hook's stdin JSON
- Extracts a topic tag from your first message in the transcript
- Captures recent git commits and uncommitted changes
- Saves the `session_id` and `tag` into the session file frontmatter
- Updates the `MEMORY.md` index
