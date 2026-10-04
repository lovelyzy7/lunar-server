#!/usr/bin/env bash
# Repo-root launcher for the Lunar Base panel (sibling of server/).
# The implementation lives in panel/start.sh, which is layout-agnostic and
# auto-initializes on first run. Extra args are forwarded (e.g. --auth).
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec bash "$ROOT/panel/start.sh" "$@"
