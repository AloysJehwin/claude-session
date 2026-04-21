package mcpserver

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/AloysJehwin/claude-session/bridge/config"
	"github.com/AloysJehwin/claude-session/bridge/relay"
)

type ToolDef struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	InputSchema map[string]interface{} `json:"inputSchema"`
}

func toolDefinitions() []ToolDef {
	return []ToolDef{
		{
			Name:        "relay_connect",
			Description: "Connect to another Claude Code session by session ID for real-time messaging.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"peer_session_id": map[string]interface{}{
						"type":        "string",
						"description": "The session ID of the peer Claude Code session to connect to.",
					},
				},
				"required": []string{"peer_session_id"},
			},
		},
		{
			Name:        "relay_send",
			Description: "Send a message to the paired Claude Code session.",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"message": map[string]interface{}{
						"type":        "string",
						"description": "The message content to send to the peer session.",
					},
				},
				"required": []string{"message"},
			},
		},
		{
			Name:        "relay_read",
			Description: "Read unread messages from the paired session. Returns all unread messages and marks them as read.",
			InputSchema: map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
		{
			Name:        "relay_status",
			Description: "Show current relay connection status including session ID, peer info, and connection state.",
			InputSchema: map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
		{
			Name:        "relay_disconnect",
			Description: "Disconnect from the paired Claude Code session.",
			InputSchema: map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
	}
}

func (s *MCPServer) handleToolCall(name string, args json.RawMessage) (interface{}, error) {
	switch name {
	case "relay_connect":
		return s.toolConnect(args)
	case "relay_send":
		return s.toolSend(args)
	case "relay_read":
		return s.toolRead()
	case "relay_status":
		return s.toolStatus()
	case "relay_disconnect":
		return s.toolDisconnect()
	default:
		return nil, fmt.Errorf("unknown tool: %s", name)
	}
}

func (s *MCPServer) toolConnect(args json.RawMessage) (interface{}, error) {
	var params struct {
		PeerSessionID string `json:"peer_session_id"`
	}
	if err := json.Unmarshal(args, &params); err != nil {
		return nil, fmt.Errorf("invalid arguments: %w", err)
	}
	if params.PeerSessionID == "" {
		return nil, fmt.Errorf("peer_session_id is required")
	}

	if s.wsClient == nil {
		return nil, fmt.Errorf("not connected to relay server")
	}

	if err := s.wsClient.PairWith(params.PeerSessionID); err != nil {
		return nil, fmt.Errorf("pair failed: %w", err)
	}

	config.SaveStatus(&config.Status{
		Connected: true,
		Peer:      params.PeerSessionID,
		Since:     time.Now(),
	})

	return map[string]interface{}{
		"status":          "connected",
		"peer_session_id": params.PeerSessionID,
		"message":         fmt.Sprintf("Successfully paired with session %s. Use relay_send to send messages.", params.PeerSessionID),
	}, nil
}

func (s *MCPServer) toolSend(args json.RawMessage) (interface{}, error) {
	var params struct {
		Message string `json:"message"`
	}
	if err := json.Unmarshal(args, &params); err != nil {
		return nil, fmt.Errorf("invalid arguments: %w", err)
	}
	if params.Message == "" {
		return nil, fmt.Errorf("message is required")
	}

	if s.wsClient == nil || !s.wsClient.IsPaired() {
		return nil, fmt.Errorf("not paired with any session. Use relay_connect first.")
	}

	msg := relay.NewMessage(params.Message, "message")
	if err := s.wsClient.Send(msg); err != nil {
		return nil, fmt.Errorf("send failed: %w", err)
	}

	relay.WriteToOutbox(msg)

	return map[string]interface{}{
		"status":  "sent",
		"message": fmt.Sprintf("Message delivered to peer session %s.", s.wsClient.PeerID()),
	}, nil
}

func (s *MCPServer) toolRead() (interface{}, error) {
	messages, paths, err := relay.ListInbox(true)
	if err != nil {
		return nil, fmt.Errorf("read inbox: %w", err)
	}

	for _, p := range paths {
		relay.MarkAsRead(p)
	}

	if len(messages) == 0 {
		return map[string]interface{}{
			"messages": []interface{}{},
			"count":    0,
			"summary":  "No unread messages.",
		}, nil
	}

	var msgList []map[string]interface{}
	for _, m := range messages {
		msgList = append(msgList, map[string]interface{}{
			"from":      m.From,
			"content":   m.Content,
			"timestamp": m.Timestamp.Format(time.RFC3339),
		})
	}

	return map[string]interface{}{
		"messages": msgList,
		"count":    len(msgList),
		"summary":  fmt.Sprintf("%d unread message(s).", len(msgList)),
	}, nil
}

func (s *MCPServer) toolStatus() (interface{}, error) {
	result := map[string]interface{}{
		"session_id": s.sessionID,
	}

	if s.wsClient != nil && s.wsClient.IsPaired() {
		result["connected"] = true
		result["peer_session_id"] = s.wsClient.PeerID()
		st, _ := config.LoadStatus()
		if !st.Since.IsZero() {
			result["since"] = st.Since.Format(time.RFC3339)
		}
	} else {
		result["connected"] = false
	}

	unread, _, _ := relay.ListInbox(true)
	result["unread_messages"] = len(unread)

	return result, nil
}

func (s *MCPServer) toolDisconnect() (interface{}, error) {
	if s.wsClient == nil || !s.wsClient.IsPaired() {
		return map[string]interface{}{
			"status":  "not_connected",
			"message": "No active connection to disconnect.",
		}, nil
	}

	peerID := s.wsClient.PeerID()
	s.wsClient.Unpair()

	config.SaveStatus(&config.Status{Connected: false})

	return map[string]interface{}{
		"status":  "disconnected",
		"message": fmt.Sprintf("Disconnected from session %s.", peerID),
	}, nil
}
