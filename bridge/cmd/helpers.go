package cmd

import (
	"fmt"
	"os"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func defaultSessionID() string {
	if id := os.Getenv("CLAUDE_SESSION_ID"); id != "" {
		return id
	}
	hostname, _ := os.Hostname()
	return fmt.Sprintf("%s-%d", hostname, os.Getpid())
}

func defaultStore() *relay.SessionStore {
	return relay.NewSessionStore(defaultSessionID())
}
