#!/usr/bin/env bash
# Lunar Base panel one-click start (repo root, sibling of server/).
# Windows users: run panel-start.bat instead.
#
# On first run (or whenever the venv / master data / grant shim is missing)
# this automatically runs panel/setup.sh, so setup no longer has to be run
# separately. Extra args are forwarded to python -m web (e.g. --auth).
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
PANEL="$ROOT/panel"

if [ ! -f "$PANEL/web/app.py" ]; then
    echo "panel/web/app.py not found under $PANEL."
    echo "Is the Lunar Base panel checked out in the panel/ directory?"
    exit 1
fi

NEED_SETUP=0
[ -x "$PANEL/.venv/bin/python" ] || NEED_SETUP=1
[ -x "$PANEL/tools/grant/grant" ] || NEED_SETUP=1
compgen -G "$PANEL/data/masterdata/*.json" >/dev/null || NEED_SETUP=1

if [ "$NEED_SETUP" -ne 0 ]; then
    echo "Panel is not fully initialized -- running panel/setup.sh first ..."
    "$PANEL/setup.sh" || exit 1
fi

# Bind address / port are resolved in Python (panel/web/config.py) with the
# precedence: data/settings.json > LUNAR_BASE_HOST/PORT > auto-detected LAN IP.
# Set them in /settings (recommended) or in the environment.

cd "$PANEL"
exec "$PANEL/.venv/bin/python" -m web "$@"
