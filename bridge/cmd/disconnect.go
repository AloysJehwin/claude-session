package cmd

import (
	"fmt"
	"os"
	"syscall"

	"github.com/AloysJehwin/claude-session/bridge/config"
)

func Disconnect() error {
	pid, err := config.LoadPID()
	if err != nil || pid == 0 {
		fmt.Println("No active relay connection.")
		config.ClearStatus()
		return nil
	}

	proc, err := os.FindProcess(pid)
	if err != nil {
		config.ClearStatus()
		fmt.Println("Relay process not found. Cleaned up.")
		return nil
	}

	if err := proc.Signal(syscall.SIGTERM); err != nil {
		config.ClearStatus()
		fmt.Println("Relay process already stopped. Cleaned up.")
		return nil
	}

	config.ClearStatus()
	fmt.Printf("Relay process (PID %d) terminated.\n", pid)
	return nil
}
