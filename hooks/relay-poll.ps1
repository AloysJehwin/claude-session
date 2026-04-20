# relay-poll.ps1 — Polls ~/.claude/relay/inbox/ for unread messages
# Used by Claude Code to surface incoming messages from remote agents inline.

$ErrorActionPreference = "SilentlyContinue"

$relayDir = Join-Path $env:USERPROFILE ".claude" "relay"
$inboxDir = Join-Path $relayDir "inbox"

if (-not (Test-Path $inboxDir)) { exit 0 }

$files = Get-ChildItem -Path $inboxDir -Filter "msg_*.json" -ErrorAction SilentlyContinue
if (-not $files) { exit 0 }

foreach ($f in $files) {
    try {
        $msg = Get-Content $f.FullName -Raw | ConvertFrom-Json
        if (-not $msg.read) {
            $sender = $msg.from
            $text = $msg.content
            $ts = $msg.timestamp.Substring(0, 19)
            Write-Host "[From $sender at $ts]: $text"

            $msg.read = $true
            $msg | ConvertTo-Json -Depth 10 | Set-Content $f.FullName -Encoding UTF8
        }
    } catch {}
}

exit 0
