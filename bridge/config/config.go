package config

import (
	"encoding/json"
	"os"
	"path/filepath"
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
