package relay

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"fmt"
	"net"
	"os"
	"path/filepath"

	"golang.org/x/crypto/ssh"
)

type Server struct {
	Port     int
	listener net.Listener
	done     chan struct{}
}

func NewServer(port int) *Server {
	return &Server{
		Port: port,
		done: make(chan struct{}),
	}
}

func (s *Server) Listen(onTunnel func(*Tunnel, string)) error {
	signer, err := loadOrGenerateHostKey()
	if err != nil {
		return fmt.Errorf("host key: %w", err)
	}

	config := &ssh.ServerConfig{
		NoClientAuth: true,
	}
	config.AddHostKey(signer)

	addr := fmt.Sprintf(":%d", s.Port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("listen on %s: %w", addr, err)
	}
	s.listener = ln
	fmt.Printf("Relay listening on port %d\n", s.Port)

	go func() {
		<-s.done
		ln.Close()
	}()

	for {
		conn, err := ln.Accept()
		if err != nil {
			select {
			case <-s.done:
				return nil
			default:
				continue
			}
		}
		go s.handleConn(conn, config, onTunnel)
	}
}

func (s *Server) handleConn(conn net.Conn, config *ssh.ServerConfig, onTunnel func(*Tunnel, string)) {
	sshConn, chans, reqs, err := ssh.NewServerConn(conn, config)
	if err != nil {
		conn.Close()
		return
	}
	defer sshConn.Close()
	go ssh.DiscardRequests(reqs)

	peer := sshConn.RemoteAddr().String()
	tunnel, err := AcceptTunnel(chans)
	if err != nil {
		return
	}
	onTunnel(tunnel, peer)
}

func (s *Server) Stop() {
	select {
	case <-s.done:
	default:
		close(s.done)
	}
	if s.listener != nil {
		s.listener.Close()
	}
}

func loadOrGenerateHostKey() (ssh.Signer, error) {
	home, _ := os.UserHomeDir()
	keyPath := filepath.Join(home, ".claude", "relay", "host_key")

	data, err := os.ReadFile(keyPath)
	if err == nil {
		return ssh.ParsePrivateKey(data)
	}

	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}

	pemBlock, err := ssh.MarshalPrivateKey(priv, "")
	if err != nil {
		return nil, err
	}
	pemData := pem.EncodeToMemory(pemBlock)

	os.MkdirAll(filepath.Dir(keyPath), 0755)
	if err := os.WriteFile(keyPath, pemData, 0600); err != nil {
		return nil, err
	}

	return ssh.ParsePrivateKey(pemData)
}
