BINARY = claude-relay
MODULE = github.com/AloysJehwin/claude-session/bridge

.PHONY: build clean all

build:
	go build -o $(BINARY) .

all:
	GOOS=darwin GOARCH=arm64 go build -o $(BINARY)-darwin-arm64 .
	GOOS=darwin GOARCH=amd64 go build -o $(BINARY)-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o $(BINARY)-linux-amd64 .
	GOOS=windows GOARCH=amd64 go build -o $(BINARY)-windows-amd64.exe .

clean:
	rm -f $(BINARY) $(BINARY)-*
