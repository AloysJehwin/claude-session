# How It Works

Session storage, file format, context injection, and session tags.

## Session storage

Session logs are stored inside Claude Code's project memory directory:

**macOS / Linux:**

```
~/.claude/projects/<encoded-path>/memory/sessions/
```

**Windows:**

```
%USERPROFILE%\.claude\projects\<encoded-path>\memory\sessions\
```

### Path encoding

The current working directory is encoded by replacing path separators with dashes:

| Platform | Project path | Encoded |
|----------|-------------|---------|
| macOS/Linux | `/Users/foo/project` | `-Users-foo-project` |
| Windows | `C:\Users\foo\project` | `C-Users-foo-project` |

This matches Claude Code's own project path encoding, so session files live alongside Claude's native project memory.

## Session file format

Each session is a Markdown file with YAML frontmatter:

```markdown
---
name: Session 2026-04-20_215144 — fix auth token bug
description: Session ended at 2026-04-20 22:30:01
type: project
session_id: abc123-def456-789
tag: fix auth token bug
---

## Summary
Fixed the auth token refresh bug in the login flow. The refresh token TTL
was set to 0 in the staging configuration.

## Decisions
- Bumped refresh token TTL to 3600 seconds
- Added token expiry validation middleware

## What changed
Recent commits:
```
abc1234 fix: set refresh token TTL to 3600
def5678 feat: add token expiry validation
```

## Open / Next
- Deploy to staging and verify
- Add integration tests for token refresh
```

The frontmatter fields:

| Field | Description |
|-------|-------------|
| `name` | Session name with timestamp and optional tag |
| `description` | Human-readable status line |
| `type` | Always `project` (for Claude Code compatibility) |
| `session_id` | Claude Code's internal session ID (added by the SessionEnd hook) |
| `tag` | Auto-generated topic tag from first user message |

## Context injection

When you run `claude-session` (resume mode), it:

1. Finds the latest session file in the `sessions/` directory
2. Extracts three sections: **Summary**, **Decisions**, and **Open / Next**
3. Wraps them in a `[SESSION CONTEXT]` block
4. Passes the block to `claude` via `--append-system-prompt`
5. Truncates to **2000 characters** if the context is too long

The injected context looks like:

```
[SESSION CONTEXT — Previous session from 2026-04-20_215144]
## Summary
Fixed the auth token refresh bug...

## Decisions
- Bumped refresh token TTL to 3600...

## Open / Next
- Deploy to staging and verify...
[END SESSION CONTEXT]
```

## --load behavior

When you run `claude-session --load <date>`:

1. Finds the session file matching the date pattern
2. Reads the `session_id` from the file's frontmatter
3. If a `session_id` exists: launches `claude --resume <id>` (resumes the exact conversation)
4. If no `session_id`: falls back to `claude --continue` (continues the most recent conversation)
5. In both cases, session context is injected via `--append-system-prompt`

## Session tags

Tags are short topic descriptions auto-generated from your first message in the session.

**How they're created:**

1. The **SessionEnd hook** reads the transcript file (provided by Claude Code as `transcript_path` in the hook's stdin JSON)
2. It finds the first user message and extracts the first ~50 characters
3. This becomes the session's `tag`, stored in the frontmatter

**Where tags appear:**

- In `--list` output, shown in brackets next to the session date
- In the session file's frontmatter as the `tag:` field
- In `MEMORY.md`, appended to the session entry (e.g., `— fix auth token bug`)
- In the session's `name:` field (e.g., `Session 2026-04-20_215144 — fix auth token bug`)

## SessionEnd hook

The SessionEnd hook fires automatically when a Claude Code session ends. It:

1. **Reads input** from stdin as JSON containing `session_id`, `cwd`, and `transcript_path`
2. **Extracts a tag** from the first user message in the transcript
3. **Captures git changes** — recent commits (`git log --oneline -5`) and uncommitted changes (`git diff --stat HEAD`)
4. **Updates the session file** — writes git changes into the "What changed" section, adds `session_id` and `tag` to frontmatter
5. **Updates MEMORY.md** — adds the session entry to the index (with tag if available)

The hook only runs for projects that already have a `memory/` directory set up. It does nothing for projects that haven't used `claude-session`.
