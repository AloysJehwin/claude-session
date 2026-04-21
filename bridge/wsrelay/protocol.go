package wsrelay

import (
	"encoding/json"

	"github.com/AloysJehwin/claude-session/bridge/relay"
)

type FrameType string

const (
	FrameRegister   FrameType = "register"
	FrameRegistered FrameType = "registered"
	FramePair       FrameType = "pair"
	FramePaired     FrameType = "paired"
	FrameUnpair     FrameType = "unpair"
	FrameUnpaired   FrameType = "unpaired"
	FrameMessage    FrameType = "message"
	FrameError      FrameType = "error"
)

type Frame struct {
	Type          FrameType       `json:"type"`
	SessionID     string          `json:"session_id,omitempty"`
	PeerSessionID string          `json:"peer_session_id,omitempty"`
	Payload       json.RawMessage `json:"payload,omitempty"`
	Message       string          `json:"message,omitempty"`
	Reason        string          `json:"reason,omitempty"`
}

func NewRegisterFrame(sessionID string) *Frame {
	return &Frame{Type: FrameRegister, SessionID: sessionID}
}

func NewPairFrame(peerID string) *Frame {
	return &Frame{Type: FramePair, PeerSessionID: peerID}
}

func NewUnpairFrame() *Frame {
	return &Frame{Type: FrameUnpair}
}

func NewMessageFrame(msg *relay.Message) (*Frame, error) {
	data, err := json.Marshal(msg)
	if err != nil {
		return nil, err
	}
	return &Frame{Type: FrameMessage, Payload: data}, nil
}

func NewErrorFrame(message string) *Frame {
	return &Frame{Type: FrameError, Message: message}
}

func NewRegisteredFrame(sessionID string) *Frame {
	return &Frame{Type: FrameRegistered, SessionID: sessionID}
}

func NewPairedFrame(peerID string) *Frame {
	return &Frame{Type: FramePaired, PeerSessionID: peerID}
}

func NewUnpairedFrame(reason string) *Frame {
	return &Frame{Type: FrameUnpaired, Reason: reason}
}

func (f *Frame) Marshal() ([]byte, error) {
	return json.Marshal(f)
}

func UnmarshalFrame(data []byte) (*Frame, error) {
	var f Frame
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, err
	}
	return &f, nil
}

func (f *Frame) ExtractMessage() (*relay.Message, error) {
	var msg relay.Message
	if err := json.Unmarshal(f.Payload, &msg); err != nil {
		return nil, err
	}
	return &msg, nil
}
