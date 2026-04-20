# Troubleshooting

Common issues and fixes for `claude-session`.

## "command not found: claude-session"

The installer places `claude-session` in `~/.local/bin/`. If your terminal doesn't find it:

1. **Open a new terminal** — the installer updates your shell profile, but existing terminals won't pick up the change until restarted.

2. **Run directly** if you need it right now:

   **macOS / Linux:**
   ```bash
   ~/.local/bin/claude-session --new
   ```

   **Windows (PowerShell):**
   ```powershell
   & "$env:USERPROFILE\.local\bin\claude-session.ps1" --new
   ```

3. **Verify it's on your PATH:**
   ```bash
   echo $PATH | tr ':' '\n' | grep local
   ```

## "command not found: claude"

`claude-session` requires the Claude Code CLI. Install it with:

```bash
npm install -g @anthropic-ai/claude-code
```

Verify it's working:

```bash
claude --version
```

## Sessions not being logged on exit

The SessionEnd hook must be registered in Claude Code's settings. Check that it's present:

**macOS / Linux:**

Open `~/.claude/settings.json` and verify it contains:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.local/bin/session-end.sh"
          }
        ]
      }
    ]
  }
}
```

**Windows:**

Open `%USERPROFILE%\.claude\settings.json` and verify it contains:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -File \"%USERPROFILE%\\.local\\bin\\session-end.ps1\""
          }
        ]
      }
    ]
  }
}
```

If the hook is missing, re-run the installer (`bash install.sh` or `.\install.ps1`).

## Windows: execution of scripts is disabled

PowerShell's default execution policy blocks scripts. Fix it with one of:

```powershell
# For the current session only:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Or permanently for the current user:
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Then retry the install or command.

## Wrong model alias

If you get an unexpected model, check the available aliases:

```bash
claude-session --help
```

The supported shortcuts are:

| Alias | Resolves to |
|-------|-------------|
| `opus`, `o` | `claude-opus-4-6` |
| `sonnet`, `s` | `claude-sonnet-4-6` |
| `haiku`, `h` | `claude-haiku-4-5-20251001` |
| `best` | `claude-opus-4-6` |

You can also pass any full model name directly:

```bash
claude-session --model claude-sonnet-4-6 --new
```
