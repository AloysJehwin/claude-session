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

func Listen(port int) error {
	store := defaultStore()
	if err := store.EnsureDirs(); err != nil {
		return err
	}

	cfg := &config.Config{Port: port, Mode: "listener"}
	config.SaveConfig(cfg)
	config.SaveStatus(&config.Status{
		Connected: false,
		PID:       os.Getpid(),
	})
	config.SavePID(os.Getpid())

	server := relay.NewServer(port)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\nShutting down relay...")
		server.Stop()
		config.ClearStatus()
	}()

	return server.Listen(func(tunnel *relay.Tunnel, peer string) {
		fmt.Printf("Agent connected from %s\n", peer)
		config.SaveStatus(&config.Status{
			Connected: true,
			Peer:      peer,
			Since:     time.Now(),
			PID:       os.Getpid(),
		})

		watcher := relay.NewOutboxWatcher(store)
		go watcher.Watch(func(msg *relay.Message, path string) {
			if err := tunnel.Send(msg); err != nil {
				fmt.Fprintf(os.Stderr, "Send error: %v\n", err)
				return
			}
			os.Remove(path)
		})

		tunnel.ReceiveLoop(func(msg *relay.Message) {
			if _, err := store.WriteToInbox(msg); err != nil {
				fmt.Fprintf(os.Stderr, "Inbox write error: %v\n", err)
				return
			}
			fmt.Printf("[From %s]: %s\n", msg.From, msg.Content)
		})

		watcher.Stop()
		fmt.Printf("Agent %s disconnected\n", peer)
		config.SaveStatus(&config.Status{Connected: false, PID: os.Getpid()})
	})
}
