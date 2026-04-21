---
name: relay-connect
description: Connect to another Claude Code session by session ID for real-time messaging between agents.
disable-model-invocation: true
---

Connect to a peer Claude Code session for real-time messaging.

The user wants to pair with session: $ARGUMENTS

Steps:
1. Call the `relay_status` tool first to confirm we are connected to the relay server
2. Call the `relay_connect` tool with `peer_session_id` set to the session ID provided above
3. If successful, inform the user they can use `/relay-send` to send messages and `/relay-status` to check for incoming messages
4. If it fails, suggest the user verify the peer session ID and that the relay server is running (`claude-relay server`)
