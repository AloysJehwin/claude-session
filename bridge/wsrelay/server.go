package wsrelay

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"nhooyr.io/websocket"
)

type Server struct {
	hub  *Hub
	addr string
}

func NewServer(addr string) *Server {
	return &Server{
		hub:  NewHub(),
		addr: addr,
	}
}

func (s *Server) Start() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.handleWS)
	mux.HandleFunc("/", s.handleWS)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Printf("WebSocket relay server listening on %s", s.addr)
	fmt.Printf("Relay server listening on %s\n", s.addr)
	return http.ListenAndServe(s.addr, mux)
}

func (s *Server) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true,
	})
	if err != nil {
		log.Printf("WebSocket accept error: %v", err)
		return
	}

	ctx := context.Background()

	_, data, err := conn.Read(ctx)
	if err != nil {
		conn.Close(websocket.StatusProtocolError, "expected register frame")
		return
	}

	frame, err := UnmarshalFrame(data)
	if err != nil || frame.Type != FrameRegister || frame.SessionID == "" {
		sendErrorAndClose(ctx, conn, "first frame must be register with session_id")
		return
	}

	session := s.hub.Register(frame.SessionID, conn)
	defer s.hub.Unregister(frame.SessionID)

	regFrame := NewRegisteredFrame(frame.SessionID)
	regData, _ := regFrame.Marshal()
	conn.Write(ctx, websocket.MessageText, regData)

	go session.WritePump(ctx)

	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			log.Printf("Session %s read error: %v", session.ID, err)
			return
		}

		incoming, err := UnmarshalFrame(data)
		if err != nil {
			continue
		}

		s.handleFrame(ctx, session, incoming, data)
	}
}

func (s *Server) handleFrame(ctx context.Context, session *Session, frame *Frame, raw []byte) {
	switch frame.Type {
	case FramePair:
		if frame.PeerSessionID == "" {
			sendError(ctx, session, "peer_session_id required")
			return
		}
		if err := s.hub.Pair(session.ID, frame.PeerSessionID); err != nil {
			sendError(ctx, session, err.Error())
			return
		}
		resp := NewPairedFrame(frame.PeerSessionID)
		data, _ := resp.Marshal()
		session.Send <- data

	case FrameUnpair:
		s.hub.Unpair(session.ID)
		resp := NewUnpairedFrame("you disconnected")
		data, _ := resp.Marshal()
		session.Send <- data

	case FrameMessage:
		if err := s.hub.Route(session.ID, raw); err != nil {
			sendError(ctx, session, err.Error())
		}

	default:
		sendError(ctx, session, fmt.Sprintf("unexpected frame type: %s", frame.Type))
	}
}

func sendError(ctx context.Context, session *Session, msg string) {
	f := NewErrorFrame(msg)
	data, _ := f.Marshal()
	select {
	case session.Send <- data:
	default:
	}
}

func sendErrorAndClose(ctx context.Context, conn *websocket.Conn, msg string) {
	f := NewErrorFrame(msg)
	data, _ := f.Marshal()
	conn.Write(ctx, websocket.MessageText, data)
	conn.Close(websocket.StatusProtocolError, msg)
}
