package relay

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/crypto/ssh"
)

func ConnectToRemote(target string, port int) (*Tunnel, ssh.Conn, error) {
	user, host := parseTarget(target)
	addr := fmt.Sprintf("%s:%d", host, port)

	signer, err := loadClientKey()
	if err != nil {
		return nil, nil, fmt.Errorf("load SSH key: %w", err)
	}

	sshConn, _, err := DialSSH(addr, user, signer)
	if err != nil {
		return nil, nil, err
	}

	tunnel, err := OpenTunnel(sshConn)
	if err != nil {
		sshConn.Close()
		return nil, nil, err
	}

	return tunnel, sshConn, nil
}

func parseTarget(target string) (user, host string) {
	if i := strings.Index(target, "@"); i >= 0 {
		return target[:i], target[i+1:]
	}
	u := os.Getenv("USER")
	if u == "" {
		u = "root"
	}
	return u, target
}

func loadClientKey() (ssh.Signer, error) {
	home, _ := os.UserHomeDir()
	keyNames := []string{"id_ed25519", "id_rsa", "id_ecdsa"}

	for _, name := range keyNames {
		path := filepath.Join(home, ".ssh", name)
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		signer, err := ssh.ParsePrivateKey(data)
		if err != nil {
			continue
		}
		return signer, nil
	}

	relayKey := filepath.Join(home, ".claude", "relay", "host_key")
	data, err := os.ReadFile(relayKey)
	if err == nil {
		signer, err := ssh.ParsePrivateKey(data)
		if err == nil {
			return signer, nil
		}
	}

	return nil, fmt.Errorf("no SSH key found in ~/.ssh/ (tried: %v)", keyNames)
}
