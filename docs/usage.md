# Usage

Commands, flags, model shortcuts, and session management for `claude-session`.

## Your first session

Navigate to your project directory and start a new session:

```bash
cd ~/your-project
claude-session --new
```

This creates a session log, then launches Claude Code normally. Work as usual — when you exit, a hook captures what changed.

## Resuming next time

Just run `claude-session` with no flags:

```bash
claude-session
```

It automatically finds the latest session log for the current directory and injects it as context. You pick up where you left off.

## Picking a model

Use shorthand aliases as the first argument:

```bash
claude-session opus --new       # fresh session with Opus
claude-session sonnet            # resume with Sonnet
claude-session h --new           # fresh session with Haiku
```

Or use the `--model` flag with a full model name:

```bash
claude-session --model claude-opus-4-6 --new
claude-session --model claude-sonnet-4-6
```

## Managing sessions

List all sessions for the current project:

```bash
claude-session --list
```

Example output:

```
Sessions for /Users/you/your-project:
---
  2026-04-20_215144  [fix auth token bug]       Session ended at 2026-04-20 22:30:01
  2026-04-19_140322  [add user dashboard]       Session ended at 2026-04-19 15:45:12
  2026-04-18_091500                              Session ended at 2026-04-18 10:20:33
---
Load one with: claude-session --load <date>
```

Sessions with auto-generated tags (from your first message) show the tag in brackets.

Load a specific session by date or partial match:

```bash
claude-session --load 2026-04-20
claude-session --load 04-19
```

Delete a session by date:

```bash
claude-session --delete 2026-04-12
```

## Model shortcuts

| Alias | Resolves to |
|-------|-------------|
| `opus`, `o` | `claude-opus-4-6` |
| `sonnet`, `s` | `claude-sonnet-4-6` |
| `haiku`, `h` | `claude-haiku-4-5-20251001` |
| `best` | `claude-opus-4-6` |

## All commands

| Flag | Short | Description |
|------|-------|-------------|
| `--new` | `-n` | Start a fresh session |
| `--list` | `-l` | List available session logs |
| `--load <date>` | | Load a specific session by date or partial match |
| `--delete <date>` | `-d` | Delete a session by date or partial match (with confirmation) |
| `--model <name>` | `-m` | Set the model (alias or full name) |
| `--help` | `-h` | Show help |
| `--version` | `-V` | Show version |

Any unrecognized flags are passed through directly to `claude`. For example:

```bash
claude-session --new --verbose
claude-session sonnet --dangerously-skip-permissions
```
