# Agent Connect

Connect two Claude Code sessions for real-time messaging. Sessions pair by session ID and communicate through a central WebSocket relay server.

## How it works

```
┌─────────────────────────────────────────────────┐
│  WebSocket Relay Server  (claude-relay server)   │
│  Runs on localhost:7778                          │
└────────────┬────────────────────┬────────────────┘
             │ ws://              │ ws://
    ┌────────▼────────┐  ┌───────▼─────────┐
    │ Claude Code (A) │  │ Claude Code (B) │
    │ MCP tools +     │  │ MCP tools +     │
    │ /relay-* skills │  │ /relay-* skills │
    └─────────────────┘  └─────────────────┘
```

Each Claude Code session loads a `claude-relay` MCP server that connects to the relay. Sessions pair by exchanging session IDs and communicate through MCP tools.

## Quick start

### 1. Start the relay server

```bash
claude-relay server
# Output: Relay server listening on localhost:7778
```

### 2. Get your session ID

In your Claude Code session:
```
You: /relay-status
Claude: Session ID: abc-123-def
        Connected: No
        Unread messages: 0
```

### 3. Share and connect

Share your session ID with the other person. In either session:
```
You: /relay-connect <peer-session-id>
Claude: Connected to session xyz-789. Relay bridge active.
```

### 4. Send messages

```
You: /relay-send Can you check the auth module?
Claude: Message sent to peer session.

        [Reading incoming messages...]
        From peer: The refresh token TTL is 0 in staging config.
```

## Slash commands

| Command | Description |
|---------|-------------|
| `/relay-connect <session-id>` | Connect to another Claude Code session |
| `/relay-send <message>` | Send a message to the paired session |
| `/relay-status` | Show connection status and read incoming messages |

## MCP tools

These tools are available to Claude Code when the `claude-relay` MCP server is running:

| Tool | Description |
|------|-------------|
| `relay_connect` | Pair with a peer session by ID |
| `relay_send` | Send a message to the paired peer |
| `relay_read` | Read and display unread incoming messages |
| `relay_status` | Show session ID and connection state |
| `relay_disconnect` | Unpair from the current peer |

## Server commands

| Command | Description |
|---------|-------------|
| `claude-relay server [--addr HOST:PORT]` | Start WebSocket relay server (default: localhost:7778) |
| `claude-relay mcp` | Start MCP server (used by Claude Code, not run manually) |

Legacy SSH commands (`listen`, `connect`) are still available for backward compatibility.

## Configuration

The installer registers the MCP server in `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "claude-relay": {
      "command": "claude-relay",
      "args": ["mcp"],
      "env": {
        "RELAY_SERVER_URL": "http://localhost:7778"
      }
    }
  }
}
```

Skills are installed to `~/.claude/skills/relay-connect/`, `relay-send/`, and `relay-status/`.

## Relay server options

```bash
claude-relay server                        # default: localhost:7778
claude-relay server --addr 0.0.0.0:7778    # listen on all interfaces
claude-relay server --addr :9000           # custom port
```

## Message format

Messages are stored as JSON in `~/.claude/relay/inbox/` and `outbox/`:

```json
{
  "id": "a1b2c3d4-...",
  "from": "hostname",
  "timestamp": "2026-04-21T10:30:00Z",
  "type": "message",
  "content": "Can you check the auth module?",
  "read": false
}
```

## Troubleshooting

### "not connected to relay server"

The relay server isn't running. Start it:
```bash
claude-relay server
```

### "peer session not found"

The peer hasn't connected to the relay server yet. They need to:
1. Have `claude-relay` MCP server configured (run the installer)
2. Start a Claude Code session (the MCP server connects automatically)
3. Share their session ID (from `/relay-status`)

### MCP server not loading

Check `~/.claude/mcp.json` contains the `claude-relay` entry. Re-run the installer if needed.

### Messages not appearing

Use `/relay-status` to check for unread messages. The `relay_read` tool fetches them from the inbox.
