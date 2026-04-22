package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

type Config struct {
	Peer string `json:"peer"`
	Port int    `json:"port"`
	Mode string `json:"mode"` // "initiator" or "listener"
}

type Status struct {
	Connected bool      `json:"connected"`
	Peer      string    `json:"peer"`
	Since     time.Time `json:"since,omitempty"`
	PID       int       `json:"pid,omitempty"`
}

func relayDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "relay")
}

func configPath() string { return filepath.Join(relayDir(), "config.json") }
func statusPath() string { return filepath.Join(relayDir(), "status.json") }
func pidPath() string    { return filepath.Join(relayDir(), "claude-relay.pid") }

func LoadConfig() (*Config, error) {
	data, err := os.ReadFile(configPath())
	if err != nil {
		return &Config{Port: 2222}, nil
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return &Config{Port: 2222}, nil
	}
	if cfg.Port == 0 {
		cfg.Port = 2222
	}
	return &cfg, nil
}

func SaveConfig(cfg *Config) error {
	os.MkdirAll(relayDir(), 0755)
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configPath(), data, 0644)
}

func LoadStatus() (*Status, error) {
	data, err := os.ReadFile(statusPath())
	if err != nil {
		return &Status{}, nil
	}
	var st Status
	if err := json.Unmarshal(data, &st); err != nil {
		return &Status{}, nil
	}
	return &st, nil
}

func SaveStatus(st *Status) error {
	os.MkdirAll(relayDir(), 0755)
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(statusPath(), data, 0644)
}

func ClearStatus() error {
	os.Remove(statusPath())
	os.Remove(pidPath())
	return nil
}

func SessionStatusPath(sessionID string) string {
	return filepath.Join(relayDir(), sessionID, "status.json")
}

func LoadSessionStatus(sessionID string) (*Status, error) {
	data, err := os.ReadFile(SessionStatusPath(sessionID))
	if err != nil {
		return &Status{}, nil
	}
	var st Status
	if err := json.Unmarshal(data, &st); err != nil {
		return &Status{}, nil
	}
	return &st, nil
}

func SaveSessionStatus(sessionID string, st *Status) error {
	dir := filepath.Join(relayDir(), sessionID)
	os.MkdirAll(dir, 0755)
	data, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(SessionStatusPath(sessionID), data, 0644)
}

func ClearSessionStatus(sessionID string) error {
	return os.Remove(SessionStatusPath(sessionID))
}

func SavePID(pid int) error {
	os.MkdirAll(relayDir(), 0755)
	data, _ := json.Marshal(pid)
	return os.WriteFile(pidPath(), data, 0644)
}

func LoadPID() (int, error) {
	data, err := os.ReadFile(pidPath())
	if err != nil {
		return 0, err
	}
	var pid int
	if err := json.Unmarshal(data, &pid); err != nil {
		return 0, err
	}
	return pid, nil
}

// ActiveSession records which MCP server session is currently running.

type ActiveSession struct {
	SessionID string `json:"session_id"`
	PID       int    `json:"pid"`
	Since     string `json:"since"`
}

func ActiveSessionPath() string {
	return filepath.Join(relayDir(), "active-session")
}

func SaveActiveSession(sessionID string) error {
	os.MkdirAll(relayDir(), 0755)
	pid := os.Getpid()
	as := ActiveSession{
		SessionID: sessionID,
		PID:       pid,
		Since:     time.Now().UTC().Format(time.RFC3339),
	}
	data, err := json.MarshalIndent(as, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(ActiveSessionPath(), data, 0644)
}

func LoadActiveSession() (*ActiveSession, error) {
	data, err := os.ReadFile(ActiveSessionPath())
	if err != nil {
		return nil, err
	}
	var as ActiveSession
	if err := json.Unmarshal(data, &as); err != nil {
		return nil, err
	}
	return &as, nil
}

func ClearActiveSession() error {
	as, err := LoadActiveSession()
	if err != nil {
		return nil
	}
	if as.PID == os.Getpid() {
		return os.Remove(ActiveSessionPath())
	}
	return nil
}

func IsProcessRunning(pid int) bool {
	if pid <= 0 {
		return false
	}
	err := syscall.Kill(pid, 0)
	return err == nil || err == syscall.EPERM
}
