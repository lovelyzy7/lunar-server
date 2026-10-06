#!/usr/bin/env bash
# sync-panel.sh — sync this repository's panel/ directory from a lunar-base checkout.
#
# The lunar-base repository is the source of truth for panel/ (see docs/SYNC.md).
# This script copies it over with the standard exclusions (runtime data is kept)
# and tells you whether anything changed so it can be committed.
#
# Usage:
#   ./sync-panel.sh [options]
#
# Options:
#   --base DIR     lunar-base checkout directory
#                  (default: $LUNAR_BASE_DIR, then a sibling ../lunar-base,
#                   ../../lunar-base or ~/lunar-base that looks like it)
#   --repo DIR     lunar-server repository root (default: this script's directory)
#   --no-delete    copy without deleting files that no longer exist upstream
#   --dry-run, -n  show what would change; do not touch any file
#   --setup        run panel/setup.sh after a successful sync
#   -h, --help     show this help
#
# Requires: rsync (Linux/macOS built in; Windows: use WSL or Git Bash + rsync).
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$SCRIPT_DIR"
BASE="${LUNAR_BASE_DIR:-}"
DELETE=1
DRY_RUN=0
RUN_SETUP=0

usage() {
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --base)      BASE="${2:-}"; shift 2 ;;
        --repo)      REPO="${2:-}"; shift 2 ;;
        --no-delete) DELETE=0; shift ;;
        --dry-run|-n) DRY_RUN=1; shift ;;
        --setup)     RUN_SETUP=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

# --- locate the repository and the panel directory ---------------------------
if [ ! -d "$REPO" ]; then
    echo "error: --repo directory not found: $REPO" >&2
    exit 1
fi
REPO="$(cd "$REPO" && pwd)"
PANEL="$REPO/panel"
if [ ! -f "$PANEL/web/app.py" ]; then
    echo "error: $PANEL/web/app.py not found (is --repo the lunar-server repository root?)" >&2
    exit 1
fi

# --- locate the lunar-base checkout (auto-detect when --base is omitted) -----
looks_like_base() {
    [ -f "$1/setup.sh" ] && [ -f "$1/web/app.py" ]
}
if [ -z "$BASE" ]; then
    for candidate in "$REPO/../lunar-base" "$REPO/../../lunar-base" "$HOME/lunar-base"; do
        if looks_like_base "$candidate"; then BASE="$candidate"; break; fi
    done
fi
if [ -z "$BASE" ] || [ ! -d "$BASE" ]; then
    echo "error: lunar-base checkout not found." >&2
    echo "       Pass --base DIR, or set LUNAR_BASE_DIR to its directory." >&2
    exit 1
fi
BASE="$(cd "$BASE" && pwd)"
if ! looks_like_base "$BASE"; then
    echo "error: $BASE does not look like a lunar-base checkout (setup.sh / web/app.py missing)." >&2
    exit 1
fi
if [ "$BASE" = "$PANEL" ]; then
    echo "error: --base and the panel directory are the same directory." >&2
    exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo "error: rsync is not installed." >&2
    echo "       Linux/macOS: install rsync from your package manager." >&2
    echo "       Windows: run this script inside WSL or Git Bash with rsync (or use cwRsync)." >&2
    exit 1
fi

# --- sync ---------------------------------------------------------------------
RSYNC_ARGS=(-a)
[ "$DELETE" -eq 1 ] && RSYNC_ARGS+=(--delete)
if [ "$DRY_RUN" -eq 1 ]; then
    # --checksum keeps the preview to content changes (no timestamp-only noise).
    RSYNC_ARGS+=(--dry-run --itemize-changes --checksum)
fi
RSYNC_ARGS+=(
    --exclude=.git
    --exclude=.venv
    --exclude=data
    --exclude=__pycache__
    --exclude=tools/grant/grant
    --exclude=tools/grant/grant.exe
    --exclude=tools/apktool
)

echo "==> base:  $BASE"
echo "==> panel: $PANEL"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> dry run: no files will be changed"
fi

if ! rsync "${RSYNC_ARGS[@]}" "$BASE/" "$PANEL/"; then
    echo "error: rsync failed" >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> dry run complete"
    exit 0
fi

# --- report what changed, so it can be committed ------------------------------
if command -v git >/dev/null 2>&1 && git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    changed="$(git -C "$REPO" status --short -- panel)"
    if [ -n "$changed" ]; then
        echo "==> panel/ changed:"
        printf '%s\n' "$changed"
        echo "==> next:"
        echo "    git -C \"$REPO\" add panel"
        echo "    git -C \"$REPO\" commit -m \"chore(panel): sync from lunar-base\""
        echo "    git -C \"$REPO\" push"
    else
        echo "==> panel/ is already up to date (no changes)"
    fi
fi

if [ "$RUN_SETUP" -eq 1 ]; then
    echo "==> running panel/setup.sh"
    bash "$PANEL/setup.sh" || exit 1
fi

echo "==> done"
