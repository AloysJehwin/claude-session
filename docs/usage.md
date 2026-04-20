# Usage

After install, use `claude-session` instead of `claude` in any project directory.

## Your first session

```bash
cd ~/my-project                   # macOS/Linux
cd C:\Users\you\my-project        # Windows

# Start a new session — creates a session log and launches Claude Code
claude-session --new
```

Claude Code opens normally. Work as usual. When you exit (`Ctrl+C` or `/exit`), the SessionEnd hook auto-captures your git changes into a session log.

## Resuming next time

```bash
# Just run it — auto-loads your latest session context
claude-session
```

Claude Code starts with your previous session's summary, decisions, and open items injected as context. It knows what you were working on.

## Picking a model

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

## Managing sessions

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

## All commands

```bash
claude-session                     # resume with latest session context
claude-session --new               # start a fresh session
claude-session opus --new          # fresh session with specific model
claude-session --model sonnet      # resume with specific model
claude-session --list              # list all sessions
claude-session --load 2026-04-11   # load specific session
claude-session --help              # show help
```

## Model shortcuts

| Shorthand | Model |
|-----------|-------|
| `opus`, `o` | claude-opus-4-6 |
| `sonnet`, `s` | claude-sonnet-4-6 |
| `haiku`, `h` | claude-haiku-4-5-20251001 |
| `best` | claude-opus-4-6 |

## Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--new` | `-n` | Start a fresh session (no context loaded) |
| `--list` | `-l` | List all sessions for the current directory |
| `--load <date>` | | Load a specific session by date or partial match |
| `--model <name>` | `-m` | Set the model (alias or full name) |
| `--help` | `-h` | Show help |

Any other flags are passed through to `claude` directly.
