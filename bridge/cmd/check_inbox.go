package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func CheckInbox() error {
	relayDir := relay.RelayDir()

	entries, err := os.ReadDir(relayDir)
	if err != nil {
		return nil
	}

	type unreadMsg struct {
		msg  *relay.Message
		path string
	}
	var unread []unreadMsg

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		inboxDir := filepath.Join(relayDir, entry.Name(), "inbox")
		files, err := os.ReadDir(inboxDir)
		if err != nil {
			continue
		}
		for _, f := range files {
			if f.IsDir() || !strings.HasSuffix(f.Name(), ".json") {
				continue
			}
			path := filepath.Join(inboxDir, f.Name())
			data, err := os.ReadFile(path)
			if err != nil {
				continue
			}
			var msg relay.Message
			if err := json.Unmarshal(data, &msg); err != nil {
				continue
			}
			if !msg.Read {
				unread = append(unread, unreadMsg{msg: &msg, path: path})
			}
		}
	}

	if len(unread) == 0 {
		return nil
	}

	sort.Slice(unread, func(i, j int) bool {
		return unread[i].msg.Timestamp.Before(unread[j].msg.Timestamp)
	})

	for _, u := range unread {
		ts := u.msg.Timestamp.Format("2006-01-02T15:04:05Z")
		fmt.Printf("RELAY MESSAGE from %s at %s:\n%s\n---\n", u.msg.From, ts, u.msg.Content)

		u.msg.Read = true
		data, err := json.MarshalIndent(u.msg, "", "  ")
		if err == nil {
			os.WriteFile(u.path, data, 0644)
		}
	}

	fmt.Println("You have unread relay messages above. Acknowledge them to the user and ask if they want to respond via /relay-send.")
	return nil
}
