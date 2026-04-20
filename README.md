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

```bash
git clone https://github.com/AloysJehwin/claude-session.git && cd claude-session && bash install.sh
```

<details>
<summary>Step by step</summary>

```bash
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session
bash install.sh

# Open a NEW terminal tab/window, then verify:
claude-session --help
```
</details>

**What the installer does:**

- Copies `bin/claude-session` to `~/.local/bin/`
- Copies `hooks/session-end.sh` to `~/.claude/hooks/`
- Adds the `SessionEnd` hook to `~/.claude/settings.json`
- Adds `~/.local/bin` to your PATH (in `~/.zshrc` or `~/.bashrc`)

### Windows (PowerShell)

```powershell
git clone https://github.com/AloysJehwin/claude-session.git; cd claude-session; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; .\install.ps1
```

<details>
<summary>Step by step</summary>

```powershell
git clone https://github.com/AloysJehwin/claude-session.git
cd claude-session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1

# Reopen your terminal, then verify:
claude-session --help
```
</details>

**What the installer does:**

- Copies `bin/claude-session.ps1` + `claude-session.cmd` to `%USERPROFILE%\.local\bin\`
- Copies `hooks/session-end.ps1` to `%USERPROFILE%\.claude\hooks\`
- Adds the `SessionEnd` hook to `%USERPROFILE%\.claude\settings.json`
- Adds `%USERPROFILE%\.local\bin` to your user PATH

> **Note:** The `.cmd` wrapper lets you run `claude-session` from both PowerShell and Command Prompt.

---

## Quick Start

```bash
cd ~/your-project
claude-session --new       # first time — creates a session and launches Claude Code
# ... work normally, then exit ...
claude-session             # next time — picks up where you left off
```

---

## Uninstall

**macOS / Linux:**
```bash
cd claude-session && bash uninstall.sh
```

**Windows:**
```powershell
cd claude-session; powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

---

## Project Structure

```
claude-session/
├── bin/
│   ├── claude-session         # CLI wrapper (macOS/Linux)
│   └── claude-session.ps1     # CLI wrapper (Windows)
├── hooks/
│   ├── session-end.sh         # SessionEnd hook (macOS/Linux)
│   └── session-end.ps1        # SessionEnd hook (Windows)
├── docs/
│   ├── usage.md               # Commands, flags, model shortcuts
│   ├── how-it-works.md        # Session storage, file format, internals
│   └── troubleshooting.md     # Common issues and fixes
├── install.sh / install.ps1
├── uninstall.sh / uninstall.ps1
├── LICENSE
└── README.md
```

---

## Docs

| Document | Description |
|----------|-------------|
| [Usage](docs/usage.md) | Commands, flags, model shortcuts, managing sessions |
| [How It Works](docs/how-it-works.md) | Session storage, file format, context injection, session tags |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and fixes |
