package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/AloysJehwin/claude-session/bridge/cmd"
)

const usage = `claude-relay — cross-machine Claude Code session bridge

USAGE:
  claude-relay listen [--port PORT]       Start relay listener (default port: 2222)
  claude-relay connect USER@HOST [PORT]   Connect to a remote relay listener
  claude-relay send MESSAGE               Send a message to the connected peer
  claude-relay inbox                      List unread messages
  claude-relay read                       Read the oldest unread message
  claude-relay status                     Show connection status
  claude-relay disconnect                 Tear down the connection
  claude-relay help                       Show this help
`

func main() {
	if len(os.Args) < 2 {
		fmt.Print(usage)
		os.Exit(0)
	}

	subcmd := os.Args[1]
	args := os.Args[2:]

	var err error
	switch subcmd {
	case "listen":
		port := 2222
		for i, a := range args {
			if a == "--port" && i+1 < len(args) {
				port, _ = strconv.Atoi(args[i+1])
			}
		}
		err = cmd.Listen(port)

	case "connect":
		if len(args) < 1 {
			fatal("Usage: claude-relay connect user@host [port]")
		}
		target := args[0]
		port := 2222
		if len(args) > 1 {
			port, _ = strconv.Atoi(args[1])
		}
		err = cmd.Connect(target, port)

	case "send":
		if len(args) < 1 {
			fatal("Usage: claude-relay send <message>")
		}
		err = cmd.Send(strings.Join(args, " "))

	case "inbox":
		err = cmd.Inbox()

	case "read":
		err = cmd.Read()

	case "status":
		err = cmd.Status()

	case "disconnect":
		err = cmd.Disconnect()

	case "help", "--help", "-h":
		fmt.Print(usage)

	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n", subcmd)
		fmt.Print(usage)
		os.Exit(1)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}
