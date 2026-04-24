# Troubleshooting

## Interactive menu not showing arrow keys

The interactive menu requires [gum](https://github.com/charmbracelet/gum). Without it, a numbered fallback is used.

**Install gum:**
- **macOS:** `brew install gum`
- **Debian/Ubuntu:** `sudo apt install gum`
- **Windows:** `winget install charmbracelet.gum` or `scoop install gum`

## `command not found: claude-session`

Open a **new terminal** after running the installer. The PATH change only takes effect in new shells.

Or run directly:
- **macOS/Linux:** `~/.local/bin/claude-session --help`
- **Windows:** `%USERPROFILE%\.local\bin\claude-session.cmd --help`

## `command not found: claude`

Install Claude Code first: `npm install -g @anthropic-ai/claude-code`

## Sessions not being logged on exit

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

## Windows: `execution of scripts is disabled`

Run the installer with the bypass flag:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

Or enable script execution for your user:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Wrong model alias

Run `claude-session --help` to see available shortcuts. You can always pass full model names with `--model claude-opus-4-6`.
