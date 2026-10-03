#!/usr/bin/env bash
# Server one-click start (repo root, sibling of server/).
# Runs the original interactive wizard unchanged; extra args are forwarded
# (e.g. --prefer-saved, --grpc-port 9003, --setup-only).
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVER="$ROOT/server"

if [ ! -f "$SERVER/cmd/wizard/main.go" ]; then
    echo "server/cmd/wizard not found under $SERVER."
    echo "Is the game server checked out in the server/ directory?"
    exit 1
fi

if ! command -v go >/dev/null 2>&1; then
    echo
    echo "Go 1.25+ not found on PATH. Install Go, then run ./server-start.sh again."
    exit 1
fi

cd "$SERVER"
exec go run ./cmd/wizard "$@"
