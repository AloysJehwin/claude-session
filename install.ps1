# install.ps1 — Install claude-session for Windows (PowerShell)
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$HooksDir = Join-Path $env:USERPROFILE ".claude\hooks"
$Settings = Join-Path $env:USERPROFILE ".claude\settings.json"

Write-Host "Installing claude-session..." -ForegroundColor Cyan

# 1. Install CLI wrapper (PowerShell script + batch launcher)
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}
Copy-Item (Join-Path $ScriptDir "bin\claude-session.ps1") (Join-Path $BinDir "claude-session.ps1") -Force

# Create a .cmd wrapper so you can just type "claude-session" from cmd/powershell
$cmdWrapper = @"
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%USERPROFILE%\.local\bin\claude-session.ps1" %*
"@
Set-Content -Path (Join-Path $BinDir "claude-session.cmd") -Value $cmdWrapper -Encoding ASCII

Write-Host "  Installed claude-session.ps1 + claude-session.cmd -> $BinDir" -ForegroundColor Green

# 2. Install SessionEnd hook
if (-not (Test-Path $HooksDir)) {
    New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
}
Copy-Item (Join-Path $ScriptDir "hooks\session-end.ps1") (Join-Path $HooksDir "session-end.ps1") -Force
Write-Host "  Installed session-end.ps1 -> $HooksDir" -ForegroundColor Green

# 3. Add SessionEnd hook to settings.json
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

$hookCommand = "powershell -ExecutionPolicy Bypass -NoProfile -File `"$HooksDir\session-end.ps1`""

if (Test-Path $Settings) {
    $settingsObj = Get-Content $Settings -Raw | ConvertFrom-Json

    $hasHook = $false
    if ($settingsObj.hooks -and $settingsObj.hooks.SessionEnd) {
        $hasHook = $true
    }

    if ($hasHook) {
        Write-Host "  SessionEnd hook already configured in settings.json" -ForegroundColor Yellow
    } else {
        # Add hooks using Python for reliable JSON manipulation
        $pythonScript = @"
import json
with open(r'$Settings') as f:
    s = json.load(f)
if 'hooks' not in s:
    s['hooks'] = {}
s['hooks']['SessionEnd'] = [
    {
        'hooks': [
            {
                'type': 'command',
                'command': r'$hookCommand',
                'timeout': 30
            }
        ]
    }
]
with open(r'$Settings', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
"@
        $pythonScript | python3
        if ($LASTEXITCODE -ne 0) {
            $pythonScript | python
        }
        Write-Host "  Added SessionEnd hook to $Settings" -ForegroundColor Green
    }
} else {
    $newSettings = @{
        hooks = @{
            SessionEnd = @(
                @{
                    hooks = @(
                        @{
                            type = "command"
                            command = $hookCommand
                            timeout = 30
                        }
                    )
                }
            )
        }
    }
    $newSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $Settings -Encoding UTF8
    Write-Host "  Created $Settings with SessionEnd hook" -ForegroundColor Green
}

# 4. Add ~/.local/bin to PATH (user-level)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$BinDir*") {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($currentPath)) { $BinDir } else { "$BinDir;$currentPath" }
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    Write-Host "  Added $BinDir to user PATH" -ForegroundColor Green
} else {
    Write-Host "  $BinDir already on PATH" -ForegroundColor Yellow
}

# Also update PATH for this current PowerShell session (helps immediate verification
# when installer is run as .\install.ps1 in the current shell).
if ($env:Path -notlike "*$BinDir*") {
    $env:Path = "$BinDir;$env:Path"
    Write-Host "  Added $BinDir to PATH for this current PowerShell session" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! If this install was run in a separate PowerShell process, reopen your terminal app (Windows Terminal / VS Code) once." -ForegroundColor Cyan
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  claude-session --help" -ForegroundColor White
