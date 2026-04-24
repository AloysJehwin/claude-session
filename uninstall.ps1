# uninstall.ps1 — Remove claude-session from Windows
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "SilentlyContinue"

$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$HooksDir = Join-Path $env:USERPROFILE ".claude\hooks"
$Settings = Join-Path $env:USERPROFILE ".claude\settings.json"

Write-Host "Uninstalling claude-session..." -ForegroundColor Cyan

# 1. Remove CLI wrapper
$ps1File = Join-Path $BinDir "claude-session.ps1"
$cmdFile = Join-Path $BinDir "claude-session.cmd"

if (Test-Path $ps1File) {
    Remove-Item $ps1File -Force
    Write-Host "  Removed $ps1File" -ForegroundColor Green
} else {
    Write-Host "  $ps1File not found (skipped)" -ForegroundColor Yellow
}

if (Test-Path $cmdFile) {
    Remove-Item $cmdFile -Force
    Write-Host "  Removed $cmdFile" -ForegroundColor Green
} else {
    Write-Host "  $cmdFile not found (skipped)" -ForegroundColor Yellow
}

# 2. Remove hook script
$hookFile = Join-Path $HooksDir "session-end.ps1"
if (Test-Path $hookFile) {
    Remove-Item $hookFile -Force
    Write-Host "  Removed $hookFile" -ForegroundColor Green
} else {
    Write-Host "  $hookFile not found (skipped)" -ForegroundColor Yellow
}

# 3. Remove SessionEnd hook from settings.json
if (Test-Path $Settings) {
    $pythonScript = @"
import json
with open(r'$Settings') as f:
    s = json.load(f)
if 'hooks' in s and 'SessionEnd' in s['hooks']:
    del s['hooks']['SessionEnd']
    if not s['hooks']:
        del s['hooks']
    with open(r'$Settings', 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
    print('  Removed SessionEnd hook from settings.json')
else:
    print('  No SessionEnd hook found in settings.json (skipped)')
"@
    $pythonScript | python3
    if ($LASTEXITCODE -ne 0) {
        $pythonScript | python
    }
}

# 4. Remove from PATH (optional — leave it since other tools may use ~/.local/bin)
Write-Host ""
Write-Host "Done! Session log files in ~\.claude\projects\*\memory\sessions\ are preserved." -ForegroundColor Cyan
Write-Host "Delete them manually if you want a full cleanup."
Write-Host ""
Write-Host "Note: If you installed 'gum' for interactive menus, it is not removed." -ForegroundColor Yellow
Write-Host "  To remove it:  winget uninstall charmbracelet.gum  (or scoop uninstall gum)"
Write-Host ""
Write-Host "To also remove $BinDir from PATH, run:" -ForegroundColor Yellow
Write-Host '  $p = [Environment]::GetEnvironmentVariable("Path","User") -replace [regex]::Escape("' + $BinDir + ';"), ""; [Environment]::SetEnvironmentVariable("Path", $p, "User")'
