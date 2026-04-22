package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/AloysJehwin/claude-session/bridge/config"
	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func MCPStatus() error {
	var as *config.ActiveSession
	var err error

	// Wait for the active-session file (MCP server may still be starting)
	for i := 0; i < 10; i++ {
		as, err = config.LoadActiveSession()
		if err == nil && config.IsProcessRunning(as.PID) {
			break
		}
		as = nil
		time.Sleep(500 * time.Millisecond)
	}

	// Fallback: scan relay directories for the most recent session
	if as == nil {
		as = findRecentSession()
	}

	if as == nil {
		return nil
	}

	fmt.Printf("IMPORTANT: You MUST tell the user their relay session ID in your first response.\n")
	fmt.Printf("Your relay session ID is: %s\n", as.SessionID)
	fmt.Printf("Tell the user: \"Your relay session ID is %s — share it with a peer to connect using /relay-connect %s\"\n", as.SessionID, as.SessionID)
	return nil
}

func findRecentSession() *config.ActiveSession {
	relayDir := relay.RelayDir()
	entries, err := os.ReadDir(relayDir)
	if err != nil {
		return nil
	}

	type sessionDir struct {
		name    string
		modTime time.Time
	}
	var dirs []sessionDir

	for _, e := range entries {
		if !e.IsDir() || !strings.Contains(e.Name(), "-") {
			continue
		}
		inboxDir := filepath.Join(relayDir, e.Name(), "inbox")
		info, err := os.Stat(inboxDir)
		if err != nil {
			info, err = os.Stat(filepath.Join(relayDir, e.Name()))
			if err != nil {
				continue
			}
		}
		dirs = append(dirs, sessionDir{name: e.Name(), modTime: info.ModTime()})
	}

	if len(dirs) == 0 {
		return nil
	}

	sort.Slice(dirs, func(i, j int) bool {
		return dirs[i].modTime.After(dirs[j].modTime)
	})

	return &config.ActiveSession{SessionID: dirs[0].name}
}
