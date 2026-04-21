package wsrelay_test

import (
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/AloysJehwin/claude-session/bridge/relay"
	"github.com/AloysJehwin/claude-session/bridge/wsrelay"
)

func TestClientPairAndMessage(t *testing.T) {
	srv := wsrelay.NewServer("localhost:17788")
	go srv.Start()
	time.Sleep(200 * time.Millisecond)

	clientA, err := wsrelay.Dial("http://localhost:17788", "session-A")
	if err != nil {
		t.Fatalf("dial A: %v", err)
	}
	defer clientA.Close()

	clientB, err := wsrelay.Dial("http://localhost:17788", "session-B")
	if err != nil {
		t.Fatalf("dial B: %v", err)
	}
	defer clientB.Close()

	var received *relay.Message
	var wg sync.WaitGroup
	wg.Add(1)
	clientB.OnMessage(func(msg *relay.Message) {
		received = msg
		wg.Done()
	})

	if err := clientA.PairWith("session-B"); err != nil {
		t.Fatalf("pair: %v", err)
	}

	if !clientA.IsPaired() {
		t.Fatal("A not paired")
	}

	msg := relay.NewMessage("hello from A", "message", "session-A")
	if err := clientA.Send(msg); err != nil {
		t.Fatalf("send: %v", err)
	}

	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("timeout waiting for message")
	}

	if received == nil {
		t.Fatal("no message received")
	}
	if received.Content != "hello from A" {
		t.Fatalf("wrong content: %s", received.Content)
	}
	fmt.Printf("Test passed: B received '%s'\n", received.Content)
}
