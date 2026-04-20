package relay

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"

	"golang.org/x/crypto/ssh"
)

const channelType = "claude-relay"

func sendMessage(ch ssh.Channel, msg *Message) error {
	data, err := MessageToJSON(msg)
	if err != nil {
		return err
	}
	header := make([]byte, 4)
	binary.BigEndian.PutUint32(header, uint32(len(data)))
	if _, err := ch.Write(header); err != nil {
		return err
	}
	_, err = ch.Write(data)
	return err
}

func recvMessage(ch ssh.Channel) (*Message, error) {
	header := make([]byte, 4)
	if _, err := io.ReadFull(ch, header); err != nil {
		return nil, err
	}
	size := binary.BigEndian.Uint32(header)
	if size > 1<<20 {
		return nil, fmt.Errorf("message too large: %d bytes", size)
	}
	data := make([]byte, size)
	if _, err := io.ReadFull(ch, data); err != nil {
		return nil, err
	}
	return MessageFromJSON(data)
}

type Tunnel struct {
	channel ssh.Channel
	done    chan struct{}
}

func NewTunnel(ch ssh.Channel) *Tunnel {
	return &Tunnel{
		channel: ch,
		done:    make(chan struct{}),
	}
}

func (t *Tunnel) Send(msg *Message) error {
	return sendMessage(t.channel, msg)
}

func (t *Tunnel) Receive() (*Message, error) {
	return recvMessage(t.channel)
}

func (t *Tunnel) Close() {
	select {
	case <-t.done:
	default:
		close(t.done)
	}
	t.channel.Close()
}

func (t *Tunnel) Done() <-chan struct{} {
	return t.done
}

func (t *Tunnel) ReceiveLoop(handler func(*Message)) {
	defer t.Close()
	for {
		msg, err := t.Receive()
		if err != nil {
			return
		}
		handler(msg)
	}
}

func OpenTunnel(conn ssh.Conn) (*Tunnel, error) {
	ch, _, err := conn.OpenChannel(channelType, nil)
	if err != nil {
		return nil, fmt.Errorf("open channel: %w", err)
	}
	return NewTunnel(ch), nil
}

func AcceptTunnel(chans <-chan ssh.NewChannel) (*Tunnel, error) {
	for newCh := range chans {
		if newCh.ChannelType() != channelType {
			newCh.Reject(ssh.UnknownChannelType, "unsupported channel type")
			continue
		}
		ch, _, err := newCh.Accept()
		if err != nil {
			return nil, fmt.Errorf("accept channel: %w", err)
		}
		return NewTunnel(ch), nil
	}
	return nil, fmt.Errorf("no channel received")
}

func DialSSH(addr, user string, signer ssh.Signer) (ssh.Conn, <-chan ssh.NewChannel, error) {
	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return nil, nil, fmt.Errorf("dial %s: %w", addr, err)
	}
	sshConn, chans, reqs, err := ssh.NewClientConn(conn, addr, config)
	if err != nil {
		conn.Close()
		return nil, nil, fmt.Errorf("ssh handshake: %w", err)
	}
	go ssh.DiscardRequests(reqs)
	return sshConn, chans, nil
}
