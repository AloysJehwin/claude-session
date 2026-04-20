# session-end.ps1 — Claude Code SessionEnd hook (Windows)
# Auto-captures session context when a Claude Code session ends.
# Receives JSON on stdin: { "session_id": "...", "cwd": "...", "transcript_path": "..." }

$ErrorActionPreference = "SilentlyContinue"

$CLAUDE_BASE_DIR = Join-Path $env:USERPROFILE ".claude"

# ---------------------------------------------------------------------------
# Read hook input from stdin
# ---------------------------------------------------------------------------

$input_json = [Console]::In.ReadToEnd()
$data = @{}
try {
    $data = $input_json | ConvertFrom-Json
} catch {}

$cwd = $data.cwd
$sessionId = $data.session_id
$transcriptPath = $data.transcript_path
if (-not $cwd) { $cwd = $env:CLAUDE_PROJECT_DIR }
if (-not $cwd) { $cwd = Get-Location }

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

$encoded = ($cwd -replace '[\\\/:]', '-')
$memDir = Join-Path $CLAUDE_BASE_DIR "projects" $encoded "memory"
$sessionsDir = Join-Path $memDir "sessions"
$memoryMd = Join-Path $memDir "MEMORY.md"

# Only proceed if this project has a memory system set up
if (-not (Test-Path $memDir)) { exit 0 }

if (-not (Test-Path $sessionsDir)) {
    New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Extract a topic tag from the first user message in the transcript
# ---------------------------------------------------------------------------

$sessionTag = ""
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $tagScript = @"
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if obj.get('type') != 'user':
                continue
            msg = obj.get('message', {})
            content = msg.get('content', '')
            text = ''
            if isinstance(content, list):
                for c in content:
                    if c.get('type') == 'text':
                        text = c['text']
                        break
            elif isinstance(content, str):
                text = content
            if text:
                text = ' '.join(text.split())
                if len(text) > 50:
                    text = text[:50].rsplit(' ', 1)[0]
                print(text.lower())
            break
except Exception:
    pass
"@
        $sessionTag = ($tagScript | python3 - $transcriptPath 2>$null).Trim()
    } catch {}
}

# ---------------------------------------------------------------------------
# Determine which session file to update
# ---------------------------------------------------------------------------

$sessionFile = $env:CLAUDE_SESSION_FILE

if (-not $sessionFile -or -not (Test-Path $sessionFile)) {
    $today = Get-Date -Format "yyyy-MM-dd"
    $todayFiles = Get-ChildItem -Path $sessionsDir -Filter "session_${today}*.md" -ErrorAction SilentlyContinue |
                  Sort-Object Name
    if ($todayFiles) {
        $sessionFile = $todayFiles[-1].FullName
    } else {
        $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $sessionFile = Join-Path $sessionsDir "session_$ts.md"
    }
}

# ---------------------------------------------------------------------------
# Gather git context
# ---------------------------------------------------------------------------

$gitLog = ""
$gitChanges = ""

try {
    Push-Location $cwd
    $gitCheck = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -eq 0) {
        $gitLog = (git log --oneline -5 2>$null) -join "`n"
        $gitChanges = (git diff --stat HEAD 2>$null | Select-Object -Last 5) -join "`n"
    }
    Pop-Location
} catch {}

# ---------------------------------------------------------------------------
# Write or update session file
# ---------------------------------------------------------------------------

$displayDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$tsName = [System.IO.Path]::GetFileNameWithoutExtension($sessionFile)

if (Test-Path $sessionFile) {
    $content = Get-Content $sessionFile -Raw
    if ($content -match '\[None yet\]|\[Review git diff\]|\[Session ended\]') {
        # Build changes section
        $changesContent = "## What changed`n"
        if ($gitLog) {
            $changesContent += "Recent commits:`n```````n$gitLog`n```````n"
        }
        if ($gitChanges) {
            $changesContent += "Uncommitted changes:`n```````n$gitChanges`n```````n"
        }
        if (-not $gitLog -and -not $gitChanges) {
            $changesContent += "No git changes detected.`n"
        }

        # Replace the What changed section
        $content = $content -replace '(?ms)## What changed.*?(?=\n## |\z)', ($changesContent.Trim() + "`n`n")

        # Update description
        $content = $content -replace 'description: Session started at .*', "description: Session ended at $displayDate"

        # Add session_id to frontmatter if not already present
        if ($sessionId -and $content -notmatch 'session_id:') {
            $content = $content -replace '(type: project)', "`$1`nsession_id: $sessionId"
        }

        # Add tag to frontmatter if not already present
        if ($sessionTag -and $content -notmatch 'tag:') {
            $content = $content -replace '(type: project)', "`$1`ntag: $sessionTag"
        }

        # Update name to include tag
        if ($sessionTag) {
            $content = $content -replace 'name: Session (\S+)', "name: Session `$1 — $sessionTag"
        }

        Set-Content -Path $sessionFile -Value $content -Encoding UTF8
    }
} else {
    # Build git info
    $gitSection = ""
    if ($gitLog) {
        $gitSection += "Recent commits:`n```````n$gitLog`n```````n"
    }
    if ($gitChanges) {
        $gitSection += "Uncommitted changes:`n```````n$gitChanges`n```````n"
    }
    if (-not $gitLog -and -not $gitChanges) {
        $gitSection = "No git changes detected."
    }

    $sessionName = $tsName
    if ($sessionTag) { $sessionName = "$tsName — $sessionTag" }

    $fmExtra = ""
    if ($sessionId) { $fmExtra += "session_id: $sessionId`n" }
    if ($sessionTag) { $fmExtra += "tag: $sessionTag`n" }

    $newContent = @"
---
name: $sessionName
description: Session ended at $displayDate
type: project
${fmExtra}---

## Summary
[Session summary pending - to be filled in next session]

## Decisions
[Review conversation for decisions made]

## What changed
$gitSection

## Open / Next
[To be determined]
"@

    Set-Content -Path $sessionFile -Value $newContent -Encoding UTF8

    # Update MEMORY.md index
    if (Test-Path $memoryMd) {
        if ($sessionTag) {
            $entry = "- [$tsName](sessions/$tsName.md) — $sessionTag"
        } else {
            $entry = "- [$tsName](sessions/$tsName.md) — session log"
        }
        $memContent = Get-Content $memoryMd -Raw
        if ($memContent -notmatch [regex]::Escape($tsName)) {
            if ($memContent -match "## Session Logs") {
                $memContent = $memContent -replace "(## Session Logs)", "`$1`n$entry"
            } else {
                $memContent += "`n## Session Logs`n$entry`n"
            }
            Set-Content -Path $memoryMd -Value $memContent -Encoding UTF8
        }
    }
}

exit 0
