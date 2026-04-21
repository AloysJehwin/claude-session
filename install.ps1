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
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -ExecutionPolicy Bypass -NoProfile -File "%USERPROFILE%\.local\bin\claude-session.ps1" %*
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%USERPROFILE%\.local\bin\claude-session.ps1" %*
)
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

    # Broadcast WM_SETTINGCHANGE so open terminals/Explorer pick up the new PATH
    try {
        if (-not ([System.Management.Automation.PSTypeName]'Win32.NativeMethods').Type) {
            Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
        }
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x001A
        $SMTO_ABORTIFHUNG = 0x0002
        $result = [UIntPtr]::Zero
        [Win32.NativeMethods]::SendMessageTimeout(
            $HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero,
            "Environment", $SMTO_ABORTIFHUNG, 5000, [ref]$result
        ) | Out-Null
        Write-Host "  Broadcast environment change to running processes" -ForegroundColor Green
    } catch {
        Write-Host "  Note: Restart your terminal to pick up the new PATH" -ForegroundColor Yellow
    }
} else {
    Write-Host "  $BinDir already on PATH" -ForegroundColor Yellow
}

# Also update PATH for this current PowerShell session (helps immediate verification
# when installer is run as .\install.ps1 in the current shell).
if ($env:Path -notlike "*$BinDir*") {
    $env:Path = "$BinDir;$env:Path"
    Write-Host "  Added $BinDir to PATH for this current PowerShell session" -ForegroundColor Green
}

# Verify the .cmd wrapper exists and is accessible
$cmdPath = Join-Path $BinDir "claude-session.cmd"
if (Test-Path $cmdPath) {
    Write-Host "  Verified: claude-session.cmd exists at $cmdPath" -ForegroundColor Green
} else {
    Write-Host "  WARNING: claude-session.cmd was not found at $cmdPath" -ForegroundColor Red
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: If 'claude-session' is not recognized:" -ForegroundColor Yellow
Write-Host "  1. Close ALL terminal windows (PowerShell, cmd, Windows Terminal, VS Code)" -ForegroundColor Yellow
Write-Host "  2. Open a fresh terminal" -ForegroundColor Yellow
Write-Host "  3. Run: claude-session --help" -ForegroundColor White
Write-Host ""
Write-Host "To verify PATH was updated, run in a NEW terminal:" -ForegroundColor Cyan
Write-Host "  echo `$env:Path | Select-String '.local\\bin'" -ForegroundColor White
