package cmd

import (
	"fmt"

	"github.com/AloysJehwin/claude-session/bridge/config"
)

func Status() error {
	st, err := config.LoadStatus()
	if err != nil {
		return err
	}
	if !st.Connected {
		fmt.Println("Not connected.")
		return nil
	}
	fmt.Printf("Connected to: %s\n", st.Peer)
	if !st.Since.IsZero() {
		fmt.Printf("Since: %s\n", st.Since.Format("2006-01-02 15:04:05"))
	}
	if st.PID > 0 {
		fmt.Printf("Bridge PID: %d\n", st.PID)
	}
	return nil
}
