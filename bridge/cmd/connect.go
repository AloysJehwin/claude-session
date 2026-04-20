package cmd

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/AloysJehwin/claude-session/bridge/config"
	"github.com/AloysJehwin/claude-session/bridge/relay"
)

func Connect(target string, port int) error {
	if err := relay.EnsureDirs(); err != nil {
		return err
	}

	fmt.Printf("Connecting to %s:%d...\n", target, port)
	tunnel, sshConn, err := relay.ConnectToRemote(target, port)
	if err != nil {
		return err
	}
	defer sshConn.Close()

	cfg := &config.Config{Peer: target, Port: port, Mode: "initiator"}
	config.SaveConfig(cfg)
	config.SaveStatus(&config.Status{
		Connected: true,
		Peer:      target,
		Since:     time.Now(),
		PID:       os.Getpid(),
	})
	config.SavePID(os.Getpid())

	fmt.Printf("Connected to %s. Relay bridge active.\n", target)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\nDisconnecting...")
		tunnel.Close()
	}()

	watcher := relay.NewOutboxWatcher()
	go watcher.Watch(func(msg *relay.Message, path string) {
		if err := tunnel.Send(msg); err != nil {
			fmt.Fprintf(os.Stderr, "Send error: %v\n", err)
			return
		}
		os.Remove(path)
	})

	tunnel.ReceiveLoop(func(msg *relay.Message) {
		relay.WriteToInbox(msg)
		fmt.Printf("[From %s]: %s\n", msg.From, msg.Content)
	})

	watcher.Stop()
	config.SaveStatus(&config.Status{Connected: false})
	fmt.Println("Disconnected.")
	return nil
}
