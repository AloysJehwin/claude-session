package wsrelay

import (
	"context"
	"fmt"
	"log"
	"sync"

	"nhooyr.io/websocket"
)

type Session struct {
	ID   string
	Conn *websocket.Conn
	Send chan []byte
	hub  *Hub
}

type Hub struct {
	mu       sync.RWMutex
	sessions map[string]*Session
	pairs    map[string]string // bidirectional: A->B and B->A
}

func NewHub() *Hub {
	return &Hub{
		sessions: make(map[string]*Session),
		pairs:    make(map[string]string),
	}
}

func (h *Hub) Register(id string, conn *websocket.Conn) *Session {
	h.mu.Lock()
	defer h.mu.Unlock()

	if old, ok := h.sessions[id]; ok {
		old.Conn.Close(websocket.StatusGoingAway, "replaced by new connection")
		close(old.Send)
	}

	s := &Session{
		ID:   id,
		Conn: conn,
		Send: make(chan []byte, 64),
		hub:  h,
	}
	h.sessions[id] = s
	log.Printf("Session registered: %s", id)
	return s
}

func (h *Hub) Unregister(id string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if peerID, ok := h.pairs[id]; ok {
		delete(h.pairs, id)
		delete(h.pairs, peerID)
		if peer, ok := h.sessions[peerID]; ok {
			h.sendFrame(peer, NewUnpairedFrame("peer disconnected"))
		}
	}

	if s, ok := h.sessions[id]; ok {
		close(s.Send)
		delete(h.sessions, id)
	}
	log.Printf("Session unregistered: %s", id)
}

func (h *Hub) Pair(requesterID, peerID string) error {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.sessions[peerID]; !ok {
		return fmt.Errorf("session %s not found", peerID)
	}

	if existingPeer, ok := h.pairs[requesterID]; ok {
		delete(h.pairs, existingPeer)
		delete(h.pairs, requesterID)
		if peer, ok := h.sessions[existingPeer]; ok {
			h.sendFrame(peer, NewUnpairedFrame("peer paired with another session"))
		}
	}

	h.pairs[requesterID] = peerID
	h.pairs[peerID] = requesterID

	if peer, ok := h.sessions[peerID]; ok {
		h.sendFrame(peer, NewPairedFrame(requesterID))
	}

	log.Printf("Paired: %s <-> %s", requesterID, peerID)
	return nil
}

func (h *Hub) Unpair(id string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	peerID, ok := h.pairs[id]
	if !ok {
		return
	}

	delete(h.pairs, id)
	delete(h.pairs, peerID)

	if peer, ok := h.sessions[peerID]; ok {
		h.sendFrame(peer, NewUnpairedFrame("peer disconnected"))
	}
	log.Printf("Unpaired: %s <-> %s", id, peerID)
}

func (h *Hub) Route(fromID string, data []byte) error {
	h.mu.RLock()
	defer h.mu.RUnlock()

	peerID, ok := h.pairs[fromID]
	if !ok {
		return fmt.Errorf("not paired")
	}

	peer, ok := h.sessions[peerID]
	if !ok {
		return fmt.Errorf("peer session gone")
	}

	select {
	case peer.Send <- data:
		return nil
	default:
		return fmt.Errorf("peer send buffer full")
	}
}

func (h *Hub) GetPeer(id string) (string, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	peer, ok := h.pairs[id]
	return peer, ok
}

func (h *Hub) SessionExists(id string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.sessions[id]
	return ok
}

func (h *Hub) sendFrame(s *Session, f *Frame) {
	data, err := f.Marshal()
	if err != nil {
		return
	}
	select {
	case s.Send <- data:
	default:
	}
}

func (s *Session) WritePump(ctx context.Context) {
	for data := range s.Send {
		if err := s.Conn.Write(ctx, websocket.MessageText, data); err != nil {
			return
		}
	}
}
