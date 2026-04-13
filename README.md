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

## Quick Start

```bash
# 1. Clone
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session

# 2. Install
bash install.sh

# 3. Open a new terminal, then navigate to any project
cd ~/your-project

# 4. Start your first session
claude-session --new

# 5. Next time, just run — it picks up where you left off
claude-session
```

## Prerequisites

Make sure you have these installed before running the installer:

| Requirement | Check | Install |
|-------------|-------|---------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| bash 3.2+ | `bash --version` | Ships with macOS/Linux |
| python3 | `python3 --version` | [python.org](https://www.python.org/downloads/) or `brew install python3` |
| git | `git --version` | [git-scm.com](https://git-scm.com/) (optional, for capturing changes) |

## Install

### Option 1: One-line install

```bash
git clone https://github.com/AloysJehwin/claude-session.git && cd claude-session && bash install.sh
```

### Option 2: Step by step

```bash
# Clone the repo
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session

# Run the installer
bash install.sh

# Open a NEW terminal tab/window (required to pick up PATH changes)
# Verify it works
claude-session --help
```

### What the installer does

- Copies `bin/claude-session` to `~/.local/bin/`
- Copies `hooks/session-end.sh` to `~/.claude/hooks/`
- Adds the `SessionEnd` hook to `~/.claude/settings.json`
- Adds `~/.local/bin` to your PATH (in `~/.zshrc` or `~/.bashrc`)

### Uninstall

```bash
cd claude-session
bash uninstall.sh
```

## Usage

After install, use `claude-session` instead of `claude` in any project directory.

### Your first session

```bash
cd ~/my-project

# Start a new session — creates a session log and launches Claude Code
claude-session --new
```

Claude Code opens normally. Work as usual. When you exit (`Ctrl+C` or `/exit`), the SessionEnd hook auto-captures your git changes into a session log.

### Resuming next time

```bash
cd ~/my-project

# Just run it — auto-loads your latest session context
claude-session
```

Claude Code starts with your previous session's summary, decisions, and open items injected as context. It knows what you were working on.

### Picking a model

```bash
# Use shorthand aliases
claude-session opus --new          # new session with Opus
claude-session sonnet              # resume with Sonnet
claude-session h --new             # new session with Haiku

# Or full model names
claude-session --model claude-opus-4-6 --new

# Or the short flag
claude-session -m opus --new
```

### Managing sessions

```bash
# See all sessions for this project
claude-session --list

# Output:
#   Sessions for /Users/you/my-project:
#   ---
#     2026-04-13_091500  Session ended at 2026-04-13 10:30:00
#     2026-04-12_140000  Implemented auth middleware
#   ---

# Load a specific session by date
claude-session --load 2026-04-12
```

### All commands

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

## Troubleshooting

### `command not found: claude-session`

Open a **new terminal** after running `install.sh`. The PATH change only takes effect in new shells.

Or run directly: `~/.local/bin/claude-session --help`

### `command not found: claude`

Install Claude Code first: `npm install -g @anthropic-ai/claude-code`

### Sessions not being logged on exit

Check that the hook is configured:
```bash
cat ~/.claude/settings.json | python3 -m json.tool
```
Look for `"SessionEnd"` in the `"hooks"` section. If missing, re-run `bash install.sh`.

### Wrong model alias

Run `claude-session --help` to see available shortcuts. You can always pass full model names with `--model claude-opus-4-6`.
