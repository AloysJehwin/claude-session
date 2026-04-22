package cmd

import (
	"fmt"
)

func Inbox() error {
	store := defaultStore()
	messages, _, err := store.ListInbox(true)
	if err != nil {
		return err
	}
	if len(messages) == 0 {
		fmt.Println("No unread messages.")
		return nil
	}
	fmt.Printf("%d unread message(s):\n", len(messages))
	for _, msg := range messages {
		fmt.Printf("  [%s] %s: %s\n", msg.Timestamp.Format("15:04:05"), msg.From, msg.Content)
	}
	return nil
}

func Read() error {
	store := defaultStore()
	messages, paths, err := store.ListInbox(true)
	if err != nil {
		return err
	}
	if len(messages) == 0 {
		fmt.Println("No unread messages.")
		return nil
	}
	msg := messages[0]
	fmt.Printf("[From %s at %s]:\n%s\n", msg.From, msg.Timestamp.Format("2006-01-02 15:04:05"), msg.Content)
	return store.MarkAsRead(paths[0])
}
