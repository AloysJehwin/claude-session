package wsrelay

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"nhooyr.io/websocket"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

type Client struct {
	conn      *websocket.Conn
	sessionID string
	peerID    string
	mu        sync.RWMutex
	onMessage func(*relay.Message)
	done      chan struct{}
	ctx       context.Context
	cancel    context.CancelFunc
}

func Dial(serverURL, sessionID string) (*Client, error) {
	ctx, cancel := context.WithCancel(context.Background())

	conn, _, err := websocket.Dial(ctx, serverURL+"/ws", nil)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("dial %s: %w", serverURL, err)
	}

	c := &Client{
		conn:      conn,
		sessionID: sessionID,
		done:      make(chan struct{}),
		ctx:       ctx,
		cancel:    cancel,
	}

	regFrame := NewRegisterFrame(sessionID)
	data, _ := regFrame.Marshal()
	if err := conn.Write(ctx, websocket.MessageText, data); err != nil {
		conn.Close(websocket.StatusProtocolError, "register failed")
		cancel()
		return nil, fmt.Errorf("send register: %w", err)
	}

	_, resp, err := conn.Read(ctx)
	if err != nil {
		conn.Close(websocket.StatusProtocolError, "no register response")
		cancel()
		return nil, fmt.Errorf("read register response: %w", err)
	}

	frame, err := UnmarshalFrame(resp)
	if err != nil || frame.Type != FrameRegistered {
		conn.Close(websocket.StatusProtocolError, "bad register response")
		cancel()
		return nil, fmt.Errorf("unexpected register response")
	}

	go c.readLoop()
	return c, nil
}

func (c *Client) SessionID() string {
	return c.sessionID
}

func (c *Client) PeerID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.peerID
}

func (c *Client) IsPaired() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.peerID != ""
}

func (c *Client) OnMessage(handler func(*relay.Message)) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.onMessage = handler
}

func (c *Client) PairWith(peerID string) error {
	frame := NewPairFrame(peerID)
	data, _ := frame.Marshal()
	if err := c.conn.Write(c.ctx, websocket.MessageText, data); err != nil {
		return fmt.Errorf("send pair: %w", err)
	}

	select {
	case <-time.After(5 * time.Second):
		return fmt.Errorf("pair timeout")
	case <-c.done:
		return fmt.Errorf("connection closed")
	case <-func() chan struct{} {
		ch := make(chan struct{})
		go func() {
			for {
				c.mu.RLock()
				paired := c.peerID == peerID
				c.mu.RUnlock()
				if paired {
					close(ch)
					return
				}
				time.Sleep(50 * time.Millisecond)
			}
		}()
		return ch
	}():
		return nil
	}
}

func (c *Client) Send(msg *relay.Message) error {
	frame, err := NewMessageFrame(msg)
	if err != nil {
		return err
	}
	data, err := frame.Marshal()
	if err != nil {
		return err
	}
	return c.conn.Write(c.ctx, websocket.MessageText, data)
}

func (c *Client) Unpair() error {
	frame := NewUnpairFrame()
	data, _ := frame.Marshal()
	return c.conn.Write(c.ctx, websocket.MessageText, data)
}

func (c *Client) Close() error {
	c.cancel()
	select {
	case <-c.done:
	default:
		close(c.done)
	}
	return c.conn.Close(websocket.StatusNormalClosure, "bye")
}

func (c *Client) readLoop() {
	defer func() {
		select {
		case <-c.done:
		default:
			close(c.done)
		}
	}()

	for {
		_, data, err := c.conn.Read(c.ctx)
		if err != nil {
			return
		}

		frame, err := UnmarshalFrame(data)
		if err != nil {
			continue
		}

		switch frame.Type {
		case FramePaired:
			c.mu.Lock()
			c.peerID = frame.PeerSessionID
			c.mu.Unlock()

		case FrameUnpaired:
			c.mu.Lock()
			c.peerID = ""
			c.mu.Unlock()

		case FrameMessage:
			msg, err := frame.ExtractMessage()
			if err != nil {
				continue
			}
			c.mu.RLock()
			handler := c.onMessage
			c.mu.RUnlock()
			if handler != nil {
				handler(msg)
			}

		case FrameError:
			var errFrame struct {
				Message string `json:"message"`
			}
			json.Unmarshal(data, &errFrame)
		}
	}
}
