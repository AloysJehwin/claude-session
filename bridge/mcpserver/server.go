package mcpserver

import (
	"encoding/json"
	"io"
	"log"
	"os"

	"github.com/AloysJehwin/claude-session/bridge/relay"
	"github.com/AloysJehwin/claude-session/bridge/wsrelay"
)

type MCPServer struct {
	transport *StdioTransport
	sessionID string
	serverURL string
	wsClient  *wsrelay.Client
}

func New(sessionID, serverURL string) *MCPServer {
	return &MCPServer{
		transport: NewStdioTransport(),
		sessionID: sessionID,
		serverURL: serverURL,
	}
}

func (s *MCPServer) Run() error {
	relay.EnsureDirs()

	log.SetOutput(os.Stderr)

	for {
		req, err := s.transport.ReadRequest()
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}

		s.handleRequest(req)
	}
}

func (s *MCPServer) handleRequest(req *JSONRPCRequest) {
	switch req.Method {
	case "initialize":
		s.handleInitialize(req)
	case "initialized":
		s.ensureConnected()
	case "tools/list":
		s.handleToolsList(req)
	case "tools/call":
		s.handleToolsCall(req)
	case "ping":
		s.transport.SendResult(req.ID, map[string]interface{}{})
	default:
		if req.ID != nil {
			s.transport.SendError(req.ID, -32601, "method not found: "+req.Method)
		}
	}
}

func (s *MCPServer) handleInitialize(req *JSONRPCRequest) {
	s.transport.SendResult(req.ID, map[string]interface{}{
		"protocolVersion": "2024-11-05",
		"capabilities": map[string]interface{}{
			"tools": map[string]interface{}{},
		},
		"serverInfo": map[string]interface{}{
			"name":    "claude-relay",
			"version": "2.0.0",
		},
		"instructions": "Use relay tools to communicate with other Claude Code sessions. " +
			"Call relay_status to see your session ID. " +
			"Call relay_connect with a peer's session ID to pair. " +
			"Call relay_send to send messages and relay_read to check for replies.",
	})
}

func (s *MCPServer) handleToolsList(req *JSONRPCRequest) {
	s.transport.SendResult(req.ID, map[string]interface{}{
		"tools": toolDefinitions(),
	})
}

func (s *MCPServer) handleToolsCall(req *JSONRPCRequest) {
	var params struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := json.Unmarshal(req.Params, &params); err != nil {
		s.transport.SendError(req.ID, -32602, "invalid params")
		return
	}

	s.ensureConnected()

	result, err := s.handleToolCall(params.Name, params.Arguments)
	if err != nil {
		s.transport.SendResult(req.ID, map[string]interface{}{
			"content": []map[string]interface{}{
				{
					"type": "text",
					"text": "Error: " + err.Error(),
				},
			},
			"isError": true,
		})
		return
	}

	text, _ := json.MarshalIndent(result, "", "  ")
	s.transport.SendResult(req.ID, map[string]interface{}{
		"content": []map[string]interface{}{
			{
				"type": "text",
				"text": string(text),
			},
		},
	})
}

func (s *MCPServer) ensureConnected() {
	if s.wsClient != nil && s.wsClient.IsAlive() {
		return
	}
	if s.wsClient != nil {
		s.wsClient.Close()
		s.wsClient = nil
	}
	if s.serverURL == "" {
		return
	}

	client, err := wsrelay.Dial(s.serverURL, s.sessionID)
	if err != nil {
		log.Printf("Relay server not reachable at %s: %v", s.serverURL, err)
		return
	}

	s.wsClient = client
	log.Printf("Connected to relay server at %s as session %s", s.serverURL, s.sessionID)

	client.OnMessage(func(msg *relay.Message) {
		relay.WriteToInbox(msg)
		log.Printf("Received message from %s: %s", msg.From, msg.Content)
	})
}
