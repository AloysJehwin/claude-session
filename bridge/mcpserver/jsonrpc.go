package mcpserver

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
)

type JSONRPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type JSONRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  interface{}     `json:"result,omitempty"`
	Error   *JSONRPCError   `json:"error,omitempty"`
}

type JSONRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type StdioTransport struct {
	reader  *bufio.Scanner
	writer  io.Writer
}

func NewStdioTransport() *StdioTransport {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	return &StdioTransport{
		reader: scanner,
		writer: os.Stdout,
	}
}

func (t *StdioTransport) ReadRequest() (*JSONRPCRequest, error) {
	if !t.reader.Scan() {
		if err := t.reader.Err(); err != nil {
			return nil, err
		}
		return nil, io.EOF
	}
	line := t.reader.Bytes()
	var req JSONRPCRequest
	if err := json.Unmarshal(line, &req); err != nil {
		return nil, fmt.Errorf("unmarshal request: %w", err)
	}
	return &req, nil
}

func (t *StdioTransport) WriteResponse(resp *JSONRPCResponse) error {
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	_, err = t.writer.Write(data)
	return err
}

func (t *StdioTransport) SendResult(id json.RawMessage, result interface{}) error {
	return t.WriteResponse(&JSONRPCResponse{
		JSONRPC: "2.0",
		ID:      id,
		Result:  result,
	})
}

func (t *StdioTransport) SendError(id json.RawMessage, code int, message string) error {
	return t.WriteResponse(&JSONRPCResponse{
		JSONRPC: "2.0",
		ID:      id,
		Error:   &JSONRPCError{Code: code, Message: message},
	})
}
