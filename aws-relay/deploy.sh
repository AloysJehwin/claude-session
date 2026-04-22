#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Check prerequisites
for cmd in aws sam; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed."
    echo "  AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    echo "  SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
  fi
done

echo "Building..."
sam build

echo "Deploying..."
sam deploy

echo ""
echo "=== Deployment complete ==="
echo ""

STACK_NAME="claude-relay"
WS_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='WebSocketURL'].OutputValue" \
  --output text 2>/dev/null || echo "")

if [ -n "$WS_URL" ]; then
  echo "WebSocket URL: $WS_URL"
  echo ""
  echo "To use it, update ~/.claude/mcp.json:"
  echo ""
  echo '  {'
  echo '    "mcpServers": {'
  echo '      "claude-relay": {'
  echo '        "command": "claude-relay",'
  echo '        "args": ["mcp"],'
  echo '        "env": {'
  echo "          \"RELAY_SERVER_URL\": \"$WS_URL\""
  echo '        }'
  echo '      }'
  echo '    }'
  echo '  }'
  echo ""
  echo "Then restart Claude Code to pick up the change."
else
  echo "Warning: could not retrieve WebSocket URL from stack outputs."
  echo "Check the stack in the AWS console."
fi
