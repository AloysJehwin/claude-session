package relay

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
)

type Message struct {
	ID        string    `json:"id"`
	From      string    `json:"from"`
	Timestamp time.Time `json:"timestamp"`
	Type      string    `json:"type"` // "message", "status"
	Content   string    `json:"content"`
	ReplyTo   string    `json:"reply_to,omitempty"`
	Read      bool      `json:"read"`
}

func NewMessage(content, msgType string) *Message {
	hostname, _ := os.Hostname()
	return &Message{
		ID:        uuid.New().String(),
		From:      hostname,
		Timestamp: time.Now().UTC(),
		Type:      msgType,
		Content:   content,
	}
}

func RelayDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "relay")
}

func InboxDir() string  { return filepath.Join(RelayDir(), "inbox") }
func OutboxDir() string { return filepath.Join(RelayDir(), "outbox") }

func EnsureDirs() error {
	for _, d := range []string{InboxDir(), OutboxDir()} {
		if err := os.MkdirAll(d, 0755); err != nil {
			return err
		}
	}
	return nil
}

func msgFilename(msg *Message) string {
	ts := msg.Timestamp.Format("20060102_150405")
	short := msg.ID[:8]
	return fmt.Sprintf("msg_%s_%s.json", ts, short)
}

func WriteToOutbox(msg *Message) (string, error) {
	if err := EnsureDirs(); err != nil {
		return "", err
	}
	path := filepath.Join(OutboxDir(), msgFilename(msg))
	data, err := json.MarshalIndent(msg, "", "  ")
	if err != nil {
		return "", err
	}
	return path, os.WriteFile(path, data, 0644)
}

func WriteToInbox(msg *Message) (string, error) {
	if err := EnsureDirs(); err != nil {
		return "", err
	}
	path := filepath.Join(InboxDir(), msgFilename(msg))
	data, err := json.MarshalIndent(msg, "", "  ")
	if err != nil {
		return "", err
	}
	return path, os.WriteFile(path, data, 0644)
}

func ReadMessage(path string) (*Message, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var msg Message
	if err := json.Unmarshal(data, &msg); err != nil {
		return nil, err
	}
	return &msg, nil
}

func MarkAsRead(path string) error {
	msg, err := ReadMessage(path)
	if err != nil {
		return err
	}
	msg.Read = true
	data, err := json.MarshalIndent(msg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func ListInbox(unreadOnly bool) ([]*Message, []string, error) {
	entries, err := os.ReadDir(InboxDir())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, nil
		}
		return nil, nil, err
	}

	var messages []*Message
	var paths []string

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		path := filepath.Join(InboxDir(), e.Name())
		msg, err := ReadMessage(path)
		if err != nil {
			continue
		}
		if unreadOnly && msg.Read {
			continue
		}
		messages = append(messages, msg)
		paths = append(paths, path)
	}
	return messages, paths, nil
}

func ListOutbox() ([]*Message, []string, error) {
	entries, err := os.ReadDir(OutboxDir())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, nil
		}
		return nil, nil, err
	}

	var messages []*Message
	var paths []string

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		path := filepath.Join(OutboxDir(), e.Name())
		msg, err := ReadMessage(path)
		if err != nil {
			continue
		}
		messages = append(messages, msg)
		paths = append(paths, path)
	}
	return messages, paths, nil
}

func MessageToJSON(msg *Message) ([]byte, error) {
	return json.Marshal(msg)
}

func MessageFromJSON(data []byte) (*Message, error) {
	var msg Message
	if err := json.Unmarshal(data, &msg); err != nil {
		return nil, err
	}
	return &msg, nil
}
