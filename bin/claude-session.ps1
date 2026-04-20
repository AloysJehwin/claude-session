# claude-session.ps1 — Claude Code wrapper with persistent session context (Windows)
# Usage:
#   claude-session                        Resume with latest session context
#   claude-session --new                  Start a fresh session
#   claude-session --model opus --new     Fresh session with specific model
#   claude-session opus --new             Fresh session with opus (shorthand)
#   claude-session --list                 List available sessions
#   claude-session --load <id>            Load a specific session
#   claude-session --help                 Show this help

param(
    [switch]$new,
    [Alias("n")]
    [switch]$NewSession,

    [switch]$list,
    [Alias("l")]
    [switch]$ListSessions,

    [string]$load,

    [Alias("m")]
    [string]$model,

    [switch]$help,
    [Alias("h")]
    [switch]$ShowHelp,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Remaining
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

$CLAUDE_BASE_DIR = Join-Path $env:USERPROFILE ".claude"
$MAX_CONTEXT_CHARS = 2000

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

$ModelAliases = @{
    "opus"   = "claude-opus-4-6"
    "o"      = "claude-opus-4-6"
    "sonnet" = "claude-sonnet-4-6"
    "s"      = "claude-sonnet-4-6"
    "haiku"  = "claude-haiku-4-5-20251001"
    "h"      = "claude-haiku-4-5-20251001"
    "best"   = "claude-opus-4-6"
}

function Resolve-Model {
    param([string]$Name)
    if ($ModelAliases.ContainsKey($Name.ToLower())) {
        return $ModelAliases[$Name.ToLower()]
    }
    return $Name
}

function Is-ModelAlias {
    param([string]$Name)
    return $ModelAliases.ContainsKey($Name.ToLower())
}

# Windows path encoding: C:\Users\foo\project → C-Users-foo-project
function Resolve-MemoryDir {
    param([string]$Cwd)
    $encoded = $Cwd -replace '[\\\/:]', '-'
    return Join-Path $CLAUDE_BASE_DIR "projects" $encoded "memory"
}

function Ensure-SessionsDir {
    param([string]$MemDir)
    $sessionsDir = Join-Path $MemDir "sessions"
    if (-not (Test-Path $sessionsDir)) {
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
    }
    return $sessionsDir
}

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd_HHmmss"
}

function Get-DisplayDate {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# Extract a markdown section (## Header through next ## or EOF)
function Extract-Section {
    param([string]$File, [string]$Section)
    if (-not (Test-Path $File)) { return "" }

    $content = Get-Content $File -Raw
    $pattern = "(?ms)^## $Section\s*\n(.*?)(?=\n## |\z)"
    if ($content -match $pattern) {
        return "## $Section`n$($Matches[1].Trim())"
    }
    return ""
}

function Extract-SessionId {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    $match = Select-String -Path $File -Pattern "^session_id:" | Select-Object -First 1
    if ($match) { return ($match.Line -replace "^session_id:\s*", "") }
    return ""
}

function Extract-Tag {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    $match = Select-String -Path $File -Pattern "^tag:" | Select-Object -First 1
    if ($match) { return ($match.Line -replace "^tag:\s*", "") }
    return ""
}

function Build-Context {
    param([string]$SessionFile)
    if (-not (Test-Path $SessionFile)) { return "" }

    $summary = Extract-Section -File $SessionFile -Section "Summary"
    $decisions = Extract-Section -File $SessionFile -Section "Decisions"
    $openNext = Extract-Section -File $SessionFile -Section "Open / Next"

    $basename = [System.IO.Path]::GetFileNameWithoutExtension($SessionFile)
    $sessionDate = $basename -replace "^session_", ""

    $context = @"
[SESSION CONTEXT - Previous session from $sessionDate]
$summary
$decisions
$openNext
[END SESSION CONTEXT]
"@

    if ($context.Length -gt $MAX_CONTEXT_CHARS) {
        $context = $context.Substring(0, $MAX_CONTEXT_CHARS) + "`n...(truncated)`n[END SESSION CONTEXT]"
    }

    return $context
}

function Find-LatestSession {
    param([string]$SessionsDir)
    $files = Get-ChildItem -Path $SessionsDir -Filter "session_*.md" -ErrorAction SilentlyContinue |
             Sort-Object Name
    if ($files) {
        return $files[-1].FullName
    }
    return $null
}

function Create-SessionFile {
    param([string]$SessionsDir)
    $ts = Get-Timestamp
    $file = Join-Path $SessionsDir "session_$ts.md"
    $displayDate = Get-DisplayDate

    $content = @"
---
name: Session $ts
description: Session started at $displayDate
type: project
---

## Summary
[New session - in progress]

## Decisions
[None yet]

## What changed
[None yet]

## Open / Next
[To be determined]
"@

    Set-Content -Path $file -Value $content -Encoding UTF8
    return $file
}

function Update-MemoryIndex {
    param([string]$MemDir, [string]$SessionFile)
    $memoryMd = Join-Path $MemDir "MEMORY.md"
    $basename = [System.IO.Path]::GetFileNameWithoutExtension($SessionFile)
    $tag = Extract-Tag -File $SessionFile
    if ($tag) {
        $entry = "- [$basename](sessions/$basename.md) — $tag"
    } else {
        $entry = "- [$basename](sessions/$basename.md) — session log"
    }

    if (-not (Test-Path $memoryMd)) {
        $content = @"
# Memory Index

## Session Logs
$entry
"@
        Set-Content -Path $memoryMd -Value $content -Encoding UTF8
        return
    }

    $existing = Get-Content $memoryMd -Raw
    if ($existing -match [regex]::Escape($basename)) { return }

    if ($existing -match "## Session Logs") {
        $existing = $existing -replace "(## Session Logs)", "`$1`n$entry"
    } else {
        $existing += "`n## Session Logs`n$entry`n"
    }
    Set-Content -Path $memoryMd -Value $existing -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

function Show-Help {
    Write-Host @"
claude-session - Claude Code with persistent session context

USAGE:
  claude-session                          Resume with latest session context
  claude-session -new                     Start a fresh session
  claude-session -model opus -new         Fresh session with opus model
  claude-session opus -new                Same thing (shorthand)
  claude-session -list                    List available session logs
  claude-session -load <id>              Load a specific session (date or partial match)
  claude-session -help                    Show this help

MODEL SHORTCUTS:
  opus, o       -> claude-opus-4-6
  sonnet, s     -> claude-sonnet-4-6
  haiku, h      -> claude-haiku-4-5-20251001
  best          -> claude-opus-4-6

  Use as first argument:    claude-session opus -new
  Or with -model flag:      claude-session -model claude-opus-4-6 -new
  Or pass full model name:  claude-session -model claude-sonnet-4-6

EXTRA FLAGS:
  Any unrecognized flags are passed through to claude.

HOW IT WORKS:
  - Sessions are stored in ~\.claude\projects\<encoded-cwd>\memory\sessions\
  - On start, the latest session's summary is injected via --append-system-prompt
  - On exit, a SessionEnd hook auto-captures what changed (requires hook setup)
  - Use -new to start fresh without loading previous context
"@
}

function Show-List {
    $memDir = Resolve-MemoryDir -Cwd (Get-Location).Path
    $sessionsDir = Join-Path $memDir "sessions"

    if (-not (Test-Path $sessionsDir)) {
        Write-Host "No sessions found for $(Get-Location)"
        Write-Host "Start one with: claude-session -new"
        return
    }

    $files = Get-ChildItem -Path $sessionsDir -Filter "session_*.md" -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending

    if (-not $files) {
        Write-Host "No sessions found for $(Get-Location)"
        Write-Host "Start one with: claude-session -new"
        return
    }

    Write-Host "Sessions for $(Get-Location):"
    Write-Host "---"
    foreach ($f in $files) {
        $name = $f.BaseName -replace "^session_", ""
        $tag = Extract-Tag -File $f.FullName
        $desc = ""
        $match = Select-String -Path $f.FullName -Pattern "^description:" | Select-Object -First 1
        if ($match) { $desc = ($match.Line -replace "^description:\s*", "") }
        if ($tag) {
            $display = "$name  [$tag]"
        } else {
            $display = $name
        }
        Write-Host ("  {0,-45}  {1}" -f $display, $desc)
    }
    Write-Host "---"
    Write-Host "Load one with: claude-session -load <date>"
}

function Start-NewSession {
    param([string[]]$ExtraArgs)
    $memDir = Resolve-MemoryDir -Cwd (Get-Location).Path
    $sessionsDir = Ensure-SessionsDir -MemDir $memDir
    $sessionFile = Create-SessionFile -SessionsDir $sessionsDir
    Update-MemoryIndex -MemDir $memDir -SessionFile $sessionFile

    $basename = [System.IO.Path]::GetFileNameWithoutExtension($sessionFile)
    Write-Host "Created new session: $basename"
    Write-Host "Starting Claude Code (fresh session)..."

    $env:CLAUDE_SESSION_FILE = $sessionFile
    & claude @ExtraArgs
}

function Start-LoadSession {
    param([string]$Pattern, [string[]]$ExtraArgs)
    $memDir = Resolve-MemoryDir -Cwd (Get-Location).Path
    $sessionsDir = Join-Path $memDir "sessions"

    if (-not (Test-Path $sessionsDir)) {
        Write-Host "No sessions directory found. Start with: claude-session -new"
        exit 1
    }

    $match = Get-ChildItem -Path $sessionsDir -Filter "session_*${Pattern}*.md" -ErrorAction SilentlyContinue |
             Sort-Object Name | Select-Object -Last 1

    if (-not $match) {
        Write-Host "No session matching '$Pattern' found."
        Show-List
        exit 1
    }

    $context = Build-Context -SessionFile $match.FullName
    $sid = Extract-SessionId -File $match.FullName
    $basename = $match.BaseName
    Write-Host "Loading session: $basename"
    Write-Host "Starting Claude Code..."

    $env:CLAUDE_SESSION_FILE = $match.FullName
    if ($sid) {
        $args = @("--resume", $sid)
    } else {
        $args = @("--continue")
    }
    if ($context) { $args += "--append-system-prompt"; $args += $context }
    $args += $ExtraArgs
    & claude @args
}

function Start-ResumeSession {
    param([string[]]$ExtraArgs)
    $memDir = Resolve-MemoryDir -Cwd (Get-Location).Path
    $sessionsDir = Ensure-SessionsDir -MemDir $memDir
    $latest = Find-LatestSession -SessionsDir $sessionsDir

    if (-not $latest) {
        Write-Host "No previous sessions found. Starting fresh..."
        Start-NewSession -ExtraArgs $ExtraArgs
        return
    }

    $context = Build-Context -SessionFile $latest
    $basename = [System.IO.Path]::GetFileNameWithoutExtension($latest)
    Write-Host "Resuming from: $basename"
    Write-Host "Starting Claude Code..."

    $env:CLAUDE_SESSION_FILE = $latest
    $args = @("--continue")
    if ($context) { $args += "--append-system-prompt"; $args += $context }
    $args += $ExtraArgs
    & claude @args
}

# ---------------------------------------------------------------------------
# Main — parse and dispatch
# ---------------------------------------------------------------------------

# Collect passthrough args
$passthrough = @()

# Check if first remaining arg is a model alias
$resolvedModel = $model
if (-not $resolvedModel -and $Remaining.Count -gt 0 -and (Is-ModelAlias $Remaining[0])) {
    $resolvedModel = Resolve-Model $Remaining[0]
    $Remaining = $Remaining[1..($Remaining.Count - 1)]
}

if ($resolvedModel) {
    $resolvedModel = Resolve-Model $resolvedModel
    $passthrough += "--model"
    $passthrough += $resolvedModel
}

if ($Remaining) { $passthrough += $Remaining }

# Dispatch
if ($help -or $ShowHelp) {
    Show-Help
} elseif ($list -or $ListSessions) {
    Show-List
} elseif ($new -or $NewSession) {
    Start-NewSession -ExtraArgs $passthrough
} elseif ($load) {
    Start-LoadSession -Pattern $load -ExtraArgs $passthrough
} else {
    Start-ResumeSession -ExtraArgs $passthrough
}
