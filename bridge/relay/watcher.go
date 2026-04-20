package relay

import (
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Watcher struct {
	dir      string
	seen     map[string]bool
	interval time.Duration
	done     chan struct{}
}

func NewOutboxWatcher() *Watcher {
	return &Watcher{
		dir:      OutboxDir(),
		seen:     make(map[string]bool),
		interval: 500 * time.Millisecond,
		done:     make(chan struct{}),
	}
}

func (w *Watcher) Watch(handler func(msg *Message, path string)) {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-w.done:
			return
		case <-ticker.C:
			w.poll(handler)
		}
	}
}

func (w *Watcher) poll(handler func(msg *Message, path string)) {
	entries, err := os.ReadDir(w.dir)
	if err != nil {
		return
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		path := filepath.Join(w.dir, e.Name())
		if w.seen[path] {
			continue
		}
		w.seen[path] = true
		msg, err := ReadMessage(path)
		if err != nil {
			continue
		}
		handler(msg, path)
	}
}

func (w *Watcher) Stop() {
	select {
	case <-w.done:
	default:
		close(w.done)
	}
}
