#!/usr/bin/env bash
# Launches the openGym MCP server (mcp/) against the data on Fly.io.
# The MCP server reads files from a local folder, so this first copies your state file down from
# the Fly volume (read-only on the server side), then starts the server on the local copy.
# Each launch refreshes the copy, which also leaves a recent local backup of your training data.
#
# stdout is the MCP channel: everything this script says goes to stderr.
set -euo pipefail

APP="${OPENGYM_FLY_APP:-opengym-isaackm}"
UID_="${OPENGYM_UID:?set OPENGYM_UID to your openGym account id}"
MIRROR="${OPENGYM_DATA:-$HOME/.local/share/opengym-mirror}"
FLY="${FLYCTL:-$HOME/.fly/bin/flyctl}"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$MIRROR"
chmod 700 "$MIRROR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if "$FLY" ssh sftp get -a "$APP" "/data/state-$UID_.json" "$tmp/state.json" >&2 2>&1 \
   && [ -s "$tmp/state.json" ]; then
  mv "$tmp/state.json" "$MIRROR/state-$UID_.json"
  chmod 600 "$MIRROR/state-$UID_.json"
  echo "[opengym-mcp] refreshed $MIRROR/state-$UID_.json from $APP" >&2
else
  echo "[opengym-mcp] could not refresh from $APP; using the last local copy (if any)" >&2
fi

export OPENGYM_DATA="$MIRROR" OPENGYM_UID="$UID_"
exec node "$HERE/mcp/src/index.js"
