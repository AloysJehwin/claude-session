# claude-session

A CLI wrapper for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that adds **persistent session context** across conversations. Pick up where you left off — every time.

## The Problem

Claude Code starts each conversation fresh. There's no built-in way to carry context (what you discussed, what decisions were made, what's still open) from one session to the next.

## The Solution

`claude-session` wraps the `claude` CLI and:

1. **On start** — finds your latest session log and injects it into the system prompt
2. **During** — normal Claude Code experience, nothing changes
3. **On exit** — a hook auto-captures git changes and creates a session log
4. **Next time** — that session log is automatically loaded as context

```
┌──────────────────────┐
│  claude-session      │  ← you run this instead of `claude`
│  finds/creates       │
│  session context     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  claude CLI          │  ← normal Claude Code
│  (with session       │
│   context injected)  │
└──────────┬───────────┘
           │ on exit
           ▼
┌──────────────────────┐
│  SessionEnd hook     │  ← auto-captures what changed
│  writes session log  │
└──────────────────────┘
```

## Install

```bash
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session
bash install.sh
```

Then open a new terminal (to pick up PATH changes).

### What the installer does

- Copies `bin/claude-session` to `~/.local/bin/`
- Copies `hooks/session-end.sh` to `~/.claude/hooks/`
- Adds the `SessionEnd` hook to `~/.claude/settings.json`
- Adds `~/.local/bin` to your PATH (in `~/.zshrc` or `~/.bashrc`)

### Uninstall

```bash
bash uninstall.sh
```

## Usage

```bash
# Resume with latest session context (default)
claude-session

# Start a fresh session
claude-session --new

# Use a specific model
claude-session opus --new
claude-session --model sonnet

# List all sessions for the current directory
claude-session --list

# Load a specific session by date
claude-session --load 2026-04-11
```

### Model shortcuts

| Shorthand | Model |
|-----------|-------|
| `opus`, `o` | claude-opus-4-6 |
| `sonnet`, `s` | claude-sonnet-4-6 |
| `haiku`, `h` | claude-haiku-4-5-20251001 |
| `best` | claude-opus-4-6 |

```bash
claude-session opus                # resume with opus
claude-session s --new             # new session with sonnet
claude-session --model haiku       # resume with haiku
claude-session --model claude-opus-4-6  # full model name works too
```

### Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--new` | `-n` | Start a fresh session (no context loaded) |
| `--list` | `-l` | List all sessions for the current directory |
| `--load <date>` | | Load a specific session by date or partial match |
| `--model <name>` | `-m` | Set the model (alias or full name) |
| `--help` | `-h` | Show help |

Any other flags are passed through to `claude` directly.

## How It Works

### Session storage

Sessions are stored per-project in Claude Code's own directory structure:

```
~/.claude/projects/<encoded-project-path>/memory/
├── MEMORY.md              ← index of all sessions
└── sessions/
    ├── session_2026-04-11_143022.md
    ├── session_2026-04-12_091500.md
    └── ...
```

The project path is encoded the same way Claude Code does it (`/Users/foo/project` → `-Users-foo-project`), so sessions are automatically scoped to each project directory.

### Session file format

```markdown
---
name: Session 2026-04-11_143022
description: Session ended at 2026-04-11 14:35:00
type: project
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

### Context injection

When resuming, the wrapper extracts the **Summary**, **Decisions**, and **Open / Next** sections and injects them via `--append-system-prompt`. The context is truncated to 2000 characters to avoid bloating the system prompt.

### SessionEnd hook

The hook fires automatically when any Claude Code session ends. It:
- Reads the current working directory from the hook's stdin JSON
- Captures recent git commits and uncommitted changes
- Writes or updates the session log file
- Updates the `MEMORY.md` index

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- bash 3.2+ (ships with macOS)
- python3 (for the SessionEnd hook's JSON parsing)
- git (optional, for capturing changes)

## License

MIT
