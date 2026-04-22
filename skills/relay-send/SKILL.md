---
name: relay-send
description: Send a message to the paired Claude Code session.
disable-model-invocation: true
---

Send a message to the connected peer session.

Message to send: $ARGUMENTS

Steps:
1. Call the `relay_send` tool with the message content above
2. Confirm delivery to the user
3. Call `relay_read` to check if there are any new replies from the peer
