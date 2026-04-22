package cmd

import (
	"fmt"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func Send(content string) error {
	store := defaultStore()
	msg := relay.NewMessage(content, "message", defaultSessionID())
	path, err := store.WriteToOutbox(msg)
	if err != nil {
		return fmt.Errorf("write to outbox: %w", err)
	}
	fmt.Printf("Message queued: %s\n", path)
	return nil
}
