package cmd

import (
	"fmt"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func Send(content string) error {
	msg := relay.NewMessage(content, "message")
	path, err := relay.WriteToOutbox(msg)
	if err != nil {
		return fmt.Errorf("write to outbox: %w", err)
	}
	fmt.Printf("Message queued: %s\n", path)
	return nil
}
