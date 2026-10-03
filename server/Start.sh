#!/usr/bin/env bash
# One-click launcher for the Lunar Tear server (Linux/macOS).
# Windows users: double-click Start.bat instead.
#
# This preserves the original interactive wizard: it validates assets, runs
# database migrations, builds the service binaries (auth + CDN + game server)
# and launches them together. Extra arguments are forwarded to the wizard,
# e.g. ./Start.sh --prefer-saved         (reuse the saved config)
#      ./Start.sh --grpc-port 9003      (custom ports)
#      ./Start.sh --setup-only          (patching instructions, no launch)
set -u
cd "$(dirname "$0")"

if ! command -v go >/dev/null 2>&1; then
    echo
    echo "Go 1.25+ not found on PATH. Install Go, then run ./Start.sh again."
    exit 1
fi

exec go run ./cmd/wizard "$@"
