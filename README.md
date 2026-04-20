# claude-session

A CLI wrapper for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that adds **persistent session context** across conversations. Pick up where you left off — every time.

Works on **macOS**, **Linux**, and **Windows**.

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

---

## Quick Start

### macOS / Linux

```bash
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session
bash install.sh

# Open a new terminal, then:
cd ~/your-project
claude-session --new       # first time
claude-session             # next time — picks up where you left off
```

### Windows (PowerShell)

```powershell
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1

# If your terminal app was already open for a long time (Windows Terminal / VS Code),
# reopen it once to pick up user PATH updates, then:
cd C:\Users\you\your-project
claude-session --new       # first time
claude-session             # next time — picks up where you left off
```

---

## Prerequisites

| Requirement | Check | Install |
|-------------|-------|---------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| python3 | `python3 --version` | [python.org](https://www.python.org/downloads/) or `brew install python3` |
| git | `git --version` | [git-scm.com](https://git-scm.com/) (optional, for capturing changes) |
| bash 3.2+ *(macOS/Linux only)* | `bash --version` | Ships with macOS/Linux |
| PowerShell 5+ *(Windows only)* | `$PSVersionTable` | Ships with Windows 10/11 |

---

## Install

### macOS / Linux

**One-line install:**

```bash
git clone https://github.com/AloysJehwin/claude-session.git && cd claude-session && bash install.sh
```

**Step by step:**

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

**What the installer does:**

- Copies `bin/claude-session` to `~/.local/bin/`
- Copies `hooks/session-end.sh` to `~/.claude/hooks/`
- Adds the `SessionEnd` hook to `~/.claude/settings.json`
- Adds `~/.local/bin` to your PATH (in `~/.zshrc` or `~/.bashrc`)

### Windows

**One-line install (PowerShell):**

```powershell
git clone https://github.com/AloysJehwin/claude-session.git; cd claude-session; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; .\install.ps1
```

**Step by step:**

```powershell
# Clone the repo
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session

# Run the installer
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1

# If your terminal app was already open for a long time (Windows Terminal / VS Code),
# reopen it once to pick up user PATH changes.
# Verify it works
claude-session --help
```

**What the installer does:**

- Copies `bin/claude-session.ps1` + `claude-session.cmd` to `%USERPROFILE%\.local\bin\`
- Copies `hooks/session-end.ps1` to `%USERPROFILE%\.claude\hooks\`
- Adds the `SessionEnd` hook to `%USERPROFILE%\.claude\settings.json`
- Adds `%USERPROFILE%\.local\bin` to your user PATH

> **Note:** The `.cmd` wrapper lets you run `claude-session` from both PowerShell and Command Prompt without typing `powershell -File ...` every time.

---

## Uninstall

### macOS / Linux

```bash
cd claude-session
bash uninstall.sh
```

### Windows

```powershell
cd claude-session
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

---

## Usage

After install, use `claude-session` instead of `claude` in any project directory.

### Your first session

```bash
cd ~/my-project                   # macOS/Linux
cd C:\Users\you\my-project        # Windows

# Start a new session — creates a session log and launches Claude Code
claude-session --new
```

Claude Code opens normally. Work as usual. When you exit (`Ctrl+C` or `/exit`), the SessionEnd hook auto-captures your git changes into a session log.

### Resuming next time

```bash
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
#     2026-04-13_091500  [fix auth middleware bug]      Session ended at 2026-04-13 10:30:00
#     2026-04-12_140000  [implement jwt auth flow]      Session ended at 2026-04-12 15:00:00
#   ---

# Load a specific session by date — resumes the exact conversation
claude-session --load 2026-04-12
```

### All commands

```bash
claude-session                     # resume with latest session context
claude-session --new               # start a fresh session
claude-session opus --new          # fresh session with specific model
claude-session --model sonnet      # resume with specific model
claude-session --list              # list all sessions
claude-session --load 2026-04-11   # load specific session
claude-session --help              # show help
```

### Model shortcuts

| Shorthand | Model |
|-----------|-------|
| `opus`, `o` | claude-opus-4-6 |
| `sonnet`, `s` | claude-sonnet-4-6 |
| `haiku`, `h` | claude-haiku-4-5-20251001 |
| `best` | claude-opus-4-6 |

### Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--new` | `-n` | Start a fresh session (no context loaded) |
| `--list` | `-l` | List all sessions for the current directory |
| `--load <date>` | | Load a specific session by date or partial match |
| `--model <name>` | `-m` | Set the model (alias or full name) |
| `--help` | `-h` | Show help |

Any other flags are passed through to `claude` directly.

---

## How It Works

### Session storage

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

### Session file format

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

### Context injection

When resuming, the wrapper extracts the **Summary**, **Decisions**, and **Open / Next** sections and injects them via `--append-system-prompt`. The context is truncated to 2000 characters to avoid bloating the system prompt.

When using `--load`, the wrapper reads the `session_id` from the session file and uses `claude --resume <id>` to reopen the exact conversation. If the session file predates this feature (no `session_id`), it falls back to `claude --continue`.

### Session tags

Each session is automatically tagged with a short topic derived from your first message. This tag:
- Appears in `--list` output next to the date for easy identification
- Is stored in the session file frontmatter as `tag:`
- Is included in the `MEMORY.md` index

### SessionEnd hook

The hook fires automatically when any Claude Code session ends. It:
- Reads the session ID, working directory, and transcript path from the hook's stdin JSON
- Extracts a topic tag from your first message in the transcript
- Captures recent git commits and uncommitted changes
- Saves the `session_id` and `tag` into the session file frontmatter
- Updates the `MEMORY.md` index

---

## Project Structure

```
claude-session/
├── bin/
│   ├── claude-session         # CLI wrapper (macOS/Linux — bash)
│   └── claude-session.ps1     # CLI wrapper (Windows — PowerShell)
├── hooks/
│   ├── session-end.sh         # SessionEnd hook (macOS/Linux)
│   └── session-end.ps1        # SessionEnd hook (Windows)
├── install.sh                 # Installer (macOS/Linux)
├── install.ps1                # Installer (Windows)
├── uninstall.sh               # Uninstaller (macOS/Linux)
├── uninstall.ps1              # Uninstaller (Windows)
├── LICENSE
└── README.md
```

---

## Troubleshooting

### `command not found: claude-session`

Open a **new terminal** after running the installer. The PATH change only takes effect in new shells.

Or run directly:
- **macOS/Linux:** `~/.local/bin/claude-session --help`
- **Windows:** `%USERPROFILE%\.local\bin\claude-session.cmd --help`

### `command not found: claude`

Install Claude Code first: `npm install -g @anthropic-ai/claude-code`

### Sessions not being logged on exit

Check that the hook is configured:

**macOS/Linux:**
```bash
cat ~/.claude/settings.json | python3 -m json.tool
```

**Windows:**
```powershell
Get-Content ~\.claude\settings.json | python3 -m json.tool
```

Look for `"SessionEnd"` in the `"hooks"` section. If missing, re-run the installer.

### Windows: `execution of scripts is disabled`

Run the installer with the bypass flag:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

Or enable script execution for your user:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Wrong model alias

Run `claude-session --help` to see available shortcuts. You can always pass full model names with `--model claude-opus-4-6`.
