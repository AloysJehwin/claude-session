# Agent Connect

Connect two Claude Code sessions on different machines for real-time, inline communication via SSH.

## How it works

One machine starts a relay listener, the other connects. Messages flow over an SSH tunnel and appear inline in both Claude Code sessions — like a group chat between two agents.

```
[Machine A]                    SSH tunnel                    [Machine B]
Claude Code ←→ claude-relay ◄══════════════════► claude-relay ←→ Claude Code
```

## Quick start

### Machine B (receiver — start first)

```bash
claude-relay listen
# Output: Relay listening on port 2222
```

### Machine A (initiator)

In your Claude Code session, use `/agent-connect`:

```
You: /agent-connect user@192.168.1.50
Claude: Connecting to user@192.168.1.50:2222...
        Connected. Relay bridge is active.
```

Or connect directly from terminal:

```bash
claude-relay connect user@192.168.1.50
```

### Sending messages

```bash
claude-relay send "Can you check the auth module on your end?"
```

Messages from the remote agent appear in your inbox:

```bash
claude-relay inbox     # list unread messages
claude-relay read      # read oldest unread message
```

## Commands

| Command | Description |
|---------|-------------|
| `claude-relay listen [--port PORT]` | Start relay listener (default: 2222) |
| `claude-relay connect user@host [port]` | Connect to a remote relay |
| `claude-relay send <message>` | Send a message to the connected peer |
| `claude-relay inbox` | List unread messages |
| `claude-relay read` | Read the oldest unread message |
| `claude-relay status` | Show connection status |
| `claude-relay disconnect` | Tear down the connection |

## Authentication

The relay uses your existing SSH keys (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, or `~/.ssh/id_ecdsa`). No additional key setup is needed.

If no SSH keys exist, a host key is auto-generated at `~/.claude/relay/host_key`.

## Message format

Messages are stored as JSON files in `~/.claude/relay/`:

```
~/.claude/relay/
├── inbox/           # Messages received from remote agent
├── outbox/          # Messages queued for delivery
├── config.json      # Connection configuration
├── status.json      # Current connection state
└── host_key         # Auto-generated SSH host key
```

## Port configuration

Default port is 2222. To use a different port:

```bash
# Listener
claude-relay listen --port 3333

# Connector
claude-relay connect user@host 3333
```

## Inline chat flow (with Claude Code)

Once connected, the experience is conversational:

**Machine A:**
```
You: Hey, can you check the auth module? I see a token expiry bug.
Claude: [Sent to remote agent]
        [From machine-b]: The refresh token TTL is 0 in staging config. Want me to fix it?
You: Yes, bump it to 3600.
Claude: [Sent to remote agent]
        [From machine-b]: Done. Committed as abc1234.
```

**Machine B:**
```
        [From machine-a]: Hey, can you check the auth module? I see a token expiry bug.
You: The refresh token TTL is 0 in staging config. Want me to fix it?
Claude: [Sent to remote agent]
        [From machine-a]: Yes, bump it to 3600.
You: Done. Committed as abc1234.
Claude: [Sent to remote agent]
```

## Troubleshooting

### Connection refused
- Ensure the listener is running on the remote machine: `claude-relay listen`
- Check the port is open: `nc -zv host 2222`
- Verify SSH key access between machines

### No SSH keys found
Generate one: `ssh-keygen -t ed25519`

### Messages not appearing
- Check inbox: `claude-relay inbox`
- Verify connection: `claude-relay status`
- Check relay directories exist: `ls ~/.claude/relay/`
