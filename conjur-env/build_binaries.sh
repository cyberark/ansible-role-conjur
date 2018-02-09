#!/bin/bash -e

GOOS=linux   GOARCH=amd64 go build -o /pkg/conjur-env_linux -a -ldflags '-extldflags "-static"' .;
GOOS=windows GOARCH=amd64 go build -o /pkg/conjur-env_win32nt.exe -a -ldflags '-extldflags "-static"' .;
GOOS=darwin  GOARCH=amd64 go build -o /pkg/conjur-env_darwin -a -ldflags '-extldflags "-static"' .;
GOOS=freebsd GOARCH=amd64 go build -o /pkg/conjur-env_freebsd -a -ldflags '-extldflags "-static"' .;
