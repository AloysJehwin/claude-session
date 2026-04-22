# AWS Relay for Claude Code

Serverless WebSocket relay using AWS API Gateway + Lambda + DynamoDB. Replaces the local `claude-relay server` for cross-machine Claude Code session communication.

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- `claude-relay` binary installed (the Go MCP client — no changes needed)

## Deploy

```bash
cd aws-relay
bash deploy.sh
```

The script builds, deploys, and prints the WebSocket URL.

## Configure

Update `~/.claude/mcp.json` with the deployed URL:

```json
{
  "mcpServers": {
    "claude-relay": {
      "command": "claude-relay",
      "args": ["mcp"],
      "env": {
        "RELAY_SERVER_URL": "wss://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod"
      }
    }
  }
}
```

Restart Claude Code to pick up the change.

## Usage

Same as before — no workflow changes:

```
/relay-status                    # see your session ID
/relay-connect <peer-session-id> # pair with another session
/relay-send <message>            # send a message
/relay-status                    # check for replies
```

## Architecture

```
Client A ──ws──► API Gateway ──► Lambda ──► DynamoDB (state)
                     │                          │
Client B ──ws──► API Gateway ◄──────────────────┘
```

- **API Gateway WebSocket API** — accepts connections, routes frames
- **Lambda** (Python) — single function handles all frame types
- **DynamoDB** (3 tables) — connection state, pairs, reverse lookup

## Cost

Effectively free under AWS free tier. Light usage (~100 messages/day) costs < $0.05/month.

## Tear Down

```bash
aws cloudformation delete-stack --stack-name claude-relay
```
