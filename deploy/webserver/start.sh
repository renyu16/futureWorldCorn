#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PORT="${PORT:-8085}"
WEB_DIR="${WEB_DIR:-$(cd "$SCRIPT_DIR/../web" && pwd)}"

pid_alive_for_web() {
  local pid="$1"
  [[ -f .pid ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ "$(ps -p "$pid" -o comm= 2>/dev/null)" == node* ]] || return 1
}

if [[ ! -f "$WEB_DIR/index.html" ]]; then
  echo "error: web bundle not found at $WEB_DIR (run npm run build and assemble package first)" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v | sed 's/v//; s/\..*//')"
  if [[ "$NODE_MAJOR" -lt 18 ]]; then
    echo "error: node >= 18 required, found $(node -v) (run ./install-node.sh)" >&2
    exit 1
  fi
else
  echo "error: node not found (run ./install-node.sh)" >&2
  exit 1
fi

if pid_alive_for_web "$(cat .pid 2>/dev/null)"; then
  echo "already running with pid $(cat .pid)"
  exit 0
fi

if [[ -f .pid ]]; then
  echo "stale pid removed"
  rm -f .pid
fi

nohup node serve.mjs --port "$PORT" --host 0.0.0.0 --dir "$WEB_DIR" > server.log 2>&1 &
echo $! > .pid
sleep 1
if kill -0 "$(cat .pid)" 2>/dev/null; then
  echo "started on port $PORT (pid $(cat .pid)) ??? see server.log"
else
  echo "failed to start; see server.log" >&2
  rm -f .pid
  exit 1
fi